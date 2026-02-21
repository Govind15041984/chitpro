from fastapi import APIRouter, Depends, Body
from sqlalchemy.orm import Session
from uuid import UUID
from sqlalchemy import func
from datetime import datetime
from app.core.database import SessionLocal
from app.core.security import get_current_user
from app.schemas.auction_round_schema import (
    AuctionRoundCloseRequest,
    AuctionRoundResultResponse,
    LiveAuctionRoundResponse,
)
from app.services.auction_round_service import (
    open_auction_round,
    close_auction_round_rule_engine,
    get_kulukal_prize_amount,
)
from app.services.reserve_service import (get_reserve_summary)
from app.models.auction_round_model import AuctionRound
from app.models.member_ledger_model import MemberLedger
from app.models.chit_member_model import ChitMember
from app.models.chit_group_model import ChitGroup
from app.models.reserve_ledger_model import ReserveLedger


router = APIRouter(tags=["Auction Rounds"])


# =====================================================
# DB DEPENDENCY
# =====================================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# =====================================================
# OPEN AUCTION ROUND
# =====================================================
@router.post("/open/{chit_group_id}", response_model=LiveAuctionRoundResponse,)
def open_round(
    chit_group_id: UUID,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
    ):
    auction = open_auction_round(
        db=db,
        chit_group_id=chit_group_id,
        #month_no=data.month_no,
    )

    return auction

# =====================================================
# CLOSE AUCTION ROUND (CONFIRM WINNER)
# =====================================================
@router.post("/close/{auction_round_id}")
def close_round(
    auction_round_id: UUID,
    payload: dict,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    auction = db.query(AuctionRound).filter(AuctionRound.id == auction_round_id).first()
    if not auction:
        raise HTTPException(status_code=404, detail="Auction round not found")

    if auction.status != "OPEN":
        raise HTTPException(status_code=400, detail="Auction is not open")

    winning_slot_id = payload.get("winning_member_id")
    winning_bid_amount = payload.get("winning_bid_amount")

    slot = db.query(ChitMember).filter(ChitMember.id == winning_slot_id).first()
    if not slot:
        raise HTTPException(status_code=400, detail="Invalid winning slot")

    chit = db.query(ChitGroup).filter(ChitGroup.id == auction.chit_group_id).first()
    if not chit:
        raise HTTPException(status_code=400, detail="Chit group not found")

    settings = chit.settings or {}
    chit_type = settings.get("chit_type")
    chit_amount = chit.chit_amount

    monthly_due_type = settings.get("monthly_due", {}).get("type")  # FIXED / VARIABLE
    reserve_rule = settings.get("reserve_rule", {})
    dividend_rule = settings.get("dividend_rule", {})

    carry_forward = reserve_rule.get("carry_forward", False)
    allow_multiple_auction = reserve_rule.get("allow_multiple_auction", False)
    dividend_enabled = dividend_rule.get("type") == "DIVIDEND"

    is_kulukal = chit_type == "KULUKAL"
    is_auction = chit_type == "AUCTION"
    is_fixed_due = monthly_due_type == "FIXED"
    is_variable_due = monthly_due_type == "VARIABLE"

    should_use_reserve = (
        (is_kulukal and carry_forward) or
        (is_auction and is_fixed_due and carry_forward)
    )

    should_use_dividend = (
        is_auction and is_variable_due and dividend_enabled and not carry_forward
    )

    # -------------------------------
    # BUSINESS RULES
    # -------------------------------
    auction.winning_member_id = slot.id

    if is_kulukal:
        prize_rule = settings.get("prize_rule", {})
        prize_mode = prize_rule.get("mode", "FLAT")
        payout_amount = chit_amount if prize_mode == "FLAT" else get_kulukal_prize_amount(chit, auction.month_no)

        auction.payout_amount = payout_amount
        auction.winning_bid_amount = None
        auction.dividend_per_member = 0

    elif is_auction:
        winning_bid_amount = int(winning_bid_amount or 0)
        auction.winning_bid_amount = winning_bid_amount
        auction.payout_amount = chit_amount - winning_bid_amount

        # 🔥 DIVIDEND (Auction + Variable)
        if should_use_dividend:
            total_slots = (
                db.query(func.count(ChitMember.id))
                .filter(ChitMember.chit_group_id == auction.chit_group_id)
                .scalar()
            ) or 0

            dividend_pool = winning_bid_amount
            dividend_per_member = int(dividend_pool / total_slots) if total_slots > 0 else 0

            auction.dividend_per_member = dividend_per_member

            ledgers = db.query(MemberLedger).filter(
                MemberLedger.chit_group_id == auction.chit_group_id,
                MemberLedger.month_no == auction.month_no,
                MemberLedger.entry_type == "MONTHLY",
            ).all()

            for l in ledgers:
                l.dividend_amount = dividend_per_member
                l.net_payable = int(l.net_payable - dividend_per_member)  # ✅ correct field
                db.add(l)
        else:
            auction.dividend_per_member = 0

    else:
        raise HTTPException(status_code=400, detail=f"Unsupported chit type: {chit_type}")

    # -------------------------------
    # 🔥 RESERVE (FINAL + CORRECT)
    # -------------------------------
    if should_use_reserve and auction.round_no == 1:
        total_collection = (
            db.query(func.coalesce(func.sum(MemberLedger.net_payable), 0))
            .filter(
                MemberLedger.chit_group_id == auction.chit_group_id,
                MemberLedger.month_no == auction.month_no,
                MemberLedger.entry_type == "MONTHLY",
            )
            .scalar()
        )

        payout = auction.payout_amount or 0
        diff = (total_collection or 0) - payout   # 🔥 +ve = ADD, -ve = USE

        print("🔥 RESERVE DEBUG", {
            "month": auction.month_no,
            "round": auction.round_no,
            "total_collection": total_collection,
            "payout": payout,
            "diff": diff,
        })

        if diff != 0:
            db.add(
                ReserveLedger(
                    chit_group_id=auction.chit_group_id,
                    month_no=auction.month_no,
                    source=f"MONTH_{auction.month_no}_ROUND_{auction.round_no}_{'ADD' if diff > 0 else 'USE'}",
                    amount=diff,  # 🔥 negative auto reduces reserve
                    created_at=datetime.utcnow(),
                )
            )

    auction.status = "WINNER_DECIDED"

    # -------------------------------
    # EXTRA AUCTION ELIGIBILITY (UNCHANGED)
    # -------------------------------
    can_run_extra = False

    if allow_multiple_auction:
        forecast_collection = (
            db.query(func.coalesce(func.sum(MemberLedger.net_payable), 0))
            .filter(
                MemberLedger.chit_group_id == auction.chit_group_id,
                MemberLedger.month_no == auction.month_no,
                MemberLedger.entry_type == "MONTHLY",
            )
            .scalar()
        )

        reserve_summary = get_reserve_summary(db, auction.chit_group_id)
        reserve_so_far = reserve_summary["total"] or 0

        current_round_payout = auction.payout_amount or 0

        db.flush()

        total_payout_committed_after = (
            db.query(func.coalesce(func.sum(AuctionRound.payout_amount), 0))
            .filter(
                AuctionRound.chit_group_id == auction.chit_group_id,
                AuctionRound.month_no == auction.month_no,
            )
            .scalar()
        )

        available_after = forecast_collection + reserve_so_far - total_payout_committed_after
        can_run_extra = available_after >= current_round_payout

        auction.calculation_snapshot = auction.calculation_snapshot or {}
        auction.calculation_snapshot.update({
            "forecast_collection": float(forecast_collection),
            "reserve_so_far": float(reserve_so_far),
            "total_payout_committed_after": float(total_payout_committed_after),
            "available_after": float(available_after),
            "current_round_payout": float(current_round_payout),
            "can_run_extra_auction": can_run_extra,
        })
    else:
        auction.calculation_snapshot = auction.calculation_snapshot or {}
        auction.calculation_snapshot["can_run_extra_auction"] = False

    db.commit()
    db.refresh(auction)

    return {
        "auction_round_id": str(auction.id),
        "status": auction.status,
        "winning_slot_id": str(slot.id),
        "winning_member_name": slot.name,
        "winning_member_no": slot.member_no,
        "winning_bid_amount": auction.winning_bid_amount,
        "payout_amount": auction.payout_amount,
    }



# =====================================================
# GET LIVE AUCTION ROUND 
# =====================================================
@router.get("/live/{chit_group_id}")
def get_live_round(
    chit_group_id: UUID,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    chit = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not chit:
        return None

    current_month = chit.current_month_no + 1

    # 🔹 Live (latest) auction for UI
    auction = (
        db.query(AuctionRound)
        .filter(
            AuctionRound.chit_group_id == chit_group_id,
            AuctionRound.month_no == current_month,
        )
        .order_by(AuctionRound.round_no.desc())
        .first()
    )

    if not auction:
        return None

    # 🔹 Last decided round (source of truth for extra-auction eligibility)
    last_decided = (
        db.query(AuctionRound)
        .filter(
            AuctionRound.chit_group_id == chit_group_id,
            AuctionRound.month_no == current_month,
            AuctionRound.status == "WINNER_DECIDED",
        )
        .order_by(AuctionRound.round_no.desc())
        .first()
    )

    can_run_extra = False
    if last_decided and last_decided.calculation_snapshot:
        snap = last_decided.calculation_snapshot
        if isinstance(snap, str):
            import json
            snap = json.loads(snap)
        can_run_extra = snap.get("can_run_extra_auction", False)

    winner = None
    if auction.winning_member_id:
        winner = db.query(ChitMember).filter(
            ChitMember.id == auction.winning_member_id
        ).first()

    # 🔥 Chit context (as per your rules)
    group_name = chit.group_name
    chit_amount = chit.chit_amount
    duration_months = chit.duration_months

    settings = chit.settings or {}
    if isinstance(settings, str):
        import json
        settings = json.loads(settings)

    chit_type = settings.get("chit_type", "KULUKAL")

    # 🔢 Installment amount (your formula)
    installment_amount = 0
    if duration_months and duration_months > 1:
        installment_amount = int(chit_amount / (duration_months - 1))

    # 💰 Month due (your logic)
    dividend_per_member = auction.dividend_per_member or 0

    if chit_type == "AUCTION":
        monthly_due = installment_amount - dividend_per_member
        discount_amount = dividend_per_member
    else:
        monthly_due = installment_amount
        discount_amount = 0

    return {
        "id": str(auction.id),
        "group_name": group_name,
        "month_no": auction.month_no,
        "round_no": auction.round_no,
        "status": auction.status,
        "is_auto": auction.is_auto,
        "auto_reason": auction.auto_reason,
        "total_collection": auction.total_collection,

        "winning_member_id": str(auction.winning_member_id) if auction.winning_member_id else None,
        "winning_member_name": winner.name if winner else None,
        "winning_member_no": winner.member_no if winner else None,

        # 🔥 Winning bid
        "payout_amount": auction.payout_amount,

        # 🔥 WhatsApp message fields (renamed)
        "chit_amount": chit_amount,
        "chit_type": chit_type,
        "monthly_due": monthly_due,          # 👈 renamed
        "discount_amount": discount_amount,

        "payout_to": "COMPANY" if auction.is_auto and auction.auto_reason == "FOREMAN_MONTH" else "MEMBER",
        "can_run_extra_auction": can_run_extra,
    }



@router.get("/latest/{chit_group_id}",response_model=LiveAuctionRoundResponse | None,)
def get_latest_round(
    chit_group_id: UUID,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
    ):
    auction = (
        db.query(AuctionRound)
        .filter(AuctionRound.chit_group_id == chit_group_id)
        .order_by(AuctionRound.month_no.desc())
        .first()
    )
    return auction


@router.get("/preview-prize/{chit_group_id}/{month_no}")
def get_prize_preview(
    chit_group_id: UUID,
    month_no: int,
    db: Session = Depends(get_db),
):
    chit = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not chit:
        raise HTTPException(404, "Chit group not found")

    prize = get_kulukal_prize_amount(chit, month_no)

    return {
        "month_no": month_no,
        "payout_amount": prize,
    }


# =====================================================
# GET AUCTION ROUNDS OF A MONTH (FOR UI HISTORY / MULTI WINNER DISPLAY)
# =====================================================
@router.get("/month/{chit_group_id}/{month_no}")
def get_month_rounds(
    chit_group_id: UUID,
    month_no: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rounds = (
        db.query(AuctionRound)
        .filter(
            AuctionRound.chit_group_id == chit_group_id,
            AuctionRound.month_no == month_no,
        )
        .order_by(AuctionRound.round_no.asc())
        .all()
    )

    result = []
    for r in rounds:
        winner = None
        if r.winning_member_id:
            winner = db.query(ChitMember).filter(
                ChitMember.id == r.winning_member_id
            ).first()

        result.append({
            "id": str(r.id),
            "month_no": r.month_no,
            "round_no": r.round_no,
            "status": r.status,
            "payout_amount": r.payout_amount,
            "winning_member_id": str(r.winning_member_id) if r.winning_member_id else None,
            "winning_member_name": winner.name if winner else None,
            "winning_member_no": winner.member_no if winner else None,

            # 🔥 ADD THESE
            "is_auto": r.is_auto,
            "auto_reason": r.auto_reason,
        })

    return result
