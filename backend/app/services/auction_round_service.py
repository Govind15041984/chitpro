from sqlalchemy.orm import Session
import sqlalchemy as sa
from uuid import UUID
from app.exceptions import ChitStateError
from datetime import datetime
from app.core.chit_state_engine import ChitStateError
from app.models.auction_round_model import AuctionRound
from app.models.chit_member_model import ChitMember
from app.models.chit_group_model import ChitGroup
from app.models.chit_group_model import ChitGroup
from app.models.auction_round_model import AuctionRound
from app.models.member_ledger_model import MemberLedger
from app.models.reserve_ledger_model import ReserveLedger
from app.services.chit_rule_service import calculate_prize, calculate_dividend
from app.services.member_ledger_service import generate_monthly_ledger, generate_prize_entry
from app.services.chit_member_service import mark_member_prized
from app.services.chit_group_service import generate_kulukal_booklet_curve


    
def open_auction_round(
    db: Session,
    chit_group_id: UUID,
):
    chit_group = (
        db.query(ChitGroup)
        .filter(ChitGroup.id == chit_group_id)
        .first()
    )

    if not chit_group:
        raise ChitStateError("Chit group not found")

    if chit_group.lifecycle_status != "RUNNING":
        raise ChitStateError("Chit group is not running")

    active_month_no = chit_group.current_month_no + 1

    if active_month_no > chit_group.duration_months:
        raise ChitStateError("Chit already completed")

    # -----------------------------------
    # Month must be started
    # -----------------------------------
    ledger_exists = (
        db.query(MemberLedger)
        .filter(
            MemberLedger.chit_group_id == chit_group_id,
            MemberLedger.month_no == active_month_no,
        )
        .first()
    )

    if not ledger_exists:
        raise ChitStateError("Month not started. Please start month before running auction.")

    # -----------------------------------
    # Compute next round_no (supports multi-round if enabled)
    # -----------------------------------
    last_round_no = (
        db.query(sa.func.max(AuctionRound.round_no))
        .filter(
            AuctionRound.chit_group_id == chit_group_id,
            AuctionRound.month_no == active_month_no,
        )
        .scalar()
    )

    next_round_no = 1 if last_round_no is None else int(last_round_no) + 1

    # -----------------------------------
    # 🔥 Foreman Rule (NEW CLEAN MODEL)
    # -----------------------------------
    settings = chit_group.settings or {}
    foreman_rule = settings.get("foreman_rule", {})

    is_foreman_month = False

    if foreman_rule.get("mode") == "FULL_MONTH":
        when = foreman_rule.get("when")   # FIXED | ANY

        if when == "FIXED":
            fixed_month = foreman_rule.get("month_no")
            if fixed_month == active_month_no:
                is_foreman_month = True

        elif when == "ANY":
            # Foreman can claim manually later (not auto)
            is_foreman_month = False

    # -----------------------------------
    # Create Auction Round
    # -----------------------------------
    auction = AuctionRound(
        chit_group_id=chit_group_id,
        month_no=active_month_no,
        round_no=next_round_no,
        total_collection=0,
        foreman_commission=0,
        dividend_per_member=0,
        reserve_amount=0,
        payout_amount=0,
        calculation_snapshot={},
        created_at=datetime.utcnow(),
        status="OPEN",
        is_auto=False,
        auto_reason=None,
    )

    # -----------------------------------
    # 🔥 AUTO FOREMAN MONTH (FIXED MODE)
    # -----------------------------------
    if is_foreman_month:
        auction.is_auto = True
        auction.auto_reason = "FOREMAN_MONTH"
        auction.payout_amount = chit_group.chit_amount
        auction.calculation_snapshot = {
            "note": "Foreman fixed month - no auction required",
            "payout_to": "COMPANY",
            "payout_amount": chit_group.chit_amount,
            "month_no": active_month_no,
        }

        db.add(auction)
        db.commit()
        db.refresh(auction)
        return auction

    # -----------------------------------
    # Normal auction flow
    # -----------------------------------
    db.add(auction)
    db.commit()
    db.refresh(auction)

    return auction




def close_auction_round_rule_engine(
    db: Session,
    auction_round_id: UUID,
    winning_member_id: UUID,
    winning_bid_amount=None
):
    # 1️⃣ Load auction + chit group
    auction = (
        db.query(AuctionRound)
        .filter(AuctionRound.id == auction_round_id)
        .first()
    )

    if not auction:
        raise Exception("Auction round not found")

    chit_group = (
        db.query(ChitGroup)
        .filter(ChitGroup.id == auction.chit_group_id)
        .first()
    )

    if not chit_group:
        raise Exception("Chit group not found")

    settings = chit_group.settings or {}

    # 2️⃣ Load active members eligible this month
    members = (
        db.query(ChitMember)
        .filter(
            ChitMember.chit_group_id == chit_group.id,
            ChitMember.status == "ACTIVE",
            ChitMember.joined_month <= auction.month_no
        )
        .all()
    )

    total_members = len(members)
    if total_members == 0:
        raise Exception("No active members to run auction")

    # 3️⃣ Installment / monthly due
    monthly_due = settings.get("monthly_due", {}).get("amount")
    if not monthly_due:
        raise Exception("Invalid chit settings: monthly_due.amount missing")

    installment = int(monthly_due)
    total_collection = installment * total_members

    # 4️⃣ Foreman commission (safe default = 0)
    foreman_pct = settings.get("foreman_commission_pct", 0)
    foreman_commission = int(total_collection * foreman_pct / 100)

    # 5️⃣ Prize / payout calculation
    chit_type = chit_group.chit_type

    if chit_type in ["KULUKAL", "SIMPLE_KULUKAL"]:
        # Kulukal: use your booklet curve
        prize_amount = get_kulukal_prize_amount(chit_group, auction.month_no)

    elif chit_type == "AUCTION":
        if winning_bid_amount is None:
            raise Exception("Winning bid amount required for AUCTION chit")

        prize_amount = int(chit_group.chit_amount - int(winning_bid_amount))

    else:
        # Default flat chit
        prize_amount = int(chit_group.chit_amount)

    # 6️⃣ Dividend + surplus (safe fallback logic)
    available_for_dividend = total_collection - foreman_commission - prize_amount

    if available_for_dividend < 0:
        raise Exception("Invalid financials: negative available amount")

    dividend_per_member = int(available_for_dividend / total_members)
    surplus = int(available_for_dividend - (dividend_per_member * total_members))

    # 7️⃣ Monthly ledger entries (installment + dividend)
    generate_monthly_ledger(
        db=db,
        chit_group_id=chit_group.id,
        month_no=auction.month_no,
        installment=installment,
        dividend_per_member=dividend_per_member,
        members=members,
    )

    # 8️⃣ Prize ledger entry
    generate_prize_entry(
        db=db,
        chit_group_id=chit_group.id,
        winning_member_id=winning_member_id,
        month_no=auction.month_no,
        prize_amount=prize_amount,
    )

    # 9️⃣ Mark member as prized
    mark_member_prized(db, winning_member_id)

    # 🔟 Reserve ledger entry (surplus)
    if surplus > 0:
        db.add(
            ReserveLedger(
                chit_group_id=chit_group.id,
                month_no=auction.month_no,
                source="DIVIDEND_SURPLUS",
                amount=surplus
            )
        )

    # 1️⃣1️⃣ Snapshot (immutable audit record)
    snapshot = {
        "chit_type": chit_type,
        "total_collection": total_collection,
        "installment": installment,
        "foreman_commission": foreman_commission,
        "prize_amount": prize_amount,
        "dividend_per_member": dividend_per_member,
        "surplus": surplus,
        "total_members": total_members,
        "month_no": auction.month_no,
        "rules": settings,
    }

    # 1️⃣2️⃣ Close auction round
    auction.winning_member_id = winning_member_id
    auction.winning_bid_amount = winning_bid_amount
    auction.foreman_commission = foreman_commission
    auction.dividend_per_member = dividend_per_member
    auction.reserve_amount = surplus
    auction.payout_amount = prize_amount
    auction.calculation_snapshot = snapshot
    auction.status = "CLOSED"

    db.commit()
    db.refresh(auction)

    return auction

def get_next_live_auction(db: Session, admin_id: str):
    result = (
        db.query(AuctionRound, ChitGroup.group_name)
        .join(ChitGroup, ChitGroup.id == AuctionRound.chit_group_id)
        .filter(
            ChitGroup.admin_id == admin_id,
            AuctionRound.status == "OPEN"
        )
        .order_by(AuctionRound.created_at.asc()) # Earliest open round first
        .first()
    )
    
    if not result:
        return None
        
    round_data, group_name = result
    return {
        "group_name": group_name,
        "month_no": round_data.month_no,
        "payout_amount": round_data.payout_amount,
        "id": str(round_data.id)
    }

def get_kulukal_prize_amount(chit_group, month_no: int) -> int:
    chit_amount = chit_group.chit_amount
    months = chit_group.duration_months

    # Month 1 = foreman month
    if month_no == 1:
        return chit_amount

    curve = generate_kulukal_booklet_curve(chit_amount, months)
    index = month_no - 2   # Month 2 → index 0

    if index < 0 or index >= len(curve):
        raise Exception(f"Invalid month for curve: {month_no}")

    return int(curve[index])    



