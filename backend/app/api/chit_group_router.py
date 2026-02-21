from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime
from typing import List
from uuid import UUID
from app.core.database import SessionLocal
from app.core.security import get_current_user
from app.schemas.chit_rule_v2_schema import ChitRuleSettingsV2
from app.schemas.chit_group_schema import (
    ChitGroupCreateRequest,
    ChitGroupCreateResponse,
    ChitGroupPreviewResponse,
    ChitGroupListItem,
    CloseMonthResponse
)
from app.services.chit_rule_service import enrich_and_validate
from app.services.reserve_service import (get_reserve_summary)
from app.services.chit_group_service import (
    preview_chit_group_create,
    create_chit_group,
    configure_chit_group,
    activate_chit_group,
    start_chit_group,
    close_chit_group,
    close_chit_month,
    start_chit_month,
    generate_kulukal_booklet_curve,
)

from app.models.chit_group_model import ChitGroup
from app.models.member_ledger_model import MemberLedger
from app.models.reserve_ledger_model import ReserveLedger
from app.models.auction_round_model import AuctionRound
from app.models.grouplink_model import GroupLink
import logging
logger = logging.getLogger("uvicorn")

router = APIRouter(tags=["Chit Groups"])
#print("🔥 ChitGroupListItem fields:", ChitGroupListItem.model_fields)
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/preview-create", response_model=ChitGroupPreviewResponse)
def preview_create(current_user = Depends(get_current_user), db: Session = Depends(get_db)):
    admin_id = current_user["id"]
    return preview_chit_group_create(db, admin_id)


@router.post("/create", response_model=ChitGroupCreateResponse)
def create_group(
    data: ChitGroupCreateRequest,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    admin_id = current_user["id"]
    group = create_chit_group(db, admin_id, data)
    return {
        "id": str(group.id),
        "group_name": group.group_name,
        "lifecycle_status": group.lifecycle_status
    }


@router.get("")
def list_chit_groups(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    admin_id = current_user["id"]

    groups = db.query(ChitGroup).filter(
        ChitGroup.admin_id == admin_id
    ).all()

    result = []

    for g in groups:
        settings = g.settings or {}
        chit_type = settings.get("chit_type", "KULUKAL")

        # 🔥 Reserve amount (sum from reserve_ledger)
        reserve_total = (
            db.query(func.coalesce(func.sum(ReserveLedger.amount), 0))
            .filter(ReserveLedger.chit_group_id == g.id)
            .scalar()
        ) or 0

        # 🔥 Dividend earned (only for AUCTION chits)
        dividend_total = 0
        if chit_type == "AUCTION":
            dividend_total = (
                db.query(func.coalesce(func.sum(AuctionRound.dividend_per_member), 0))
                .filter(
                    AuctionRound.chit_group_id == g.id,
                    AuctionRound.status == "CLOSED"
                )
                .scalar()
            ) or 0

        # 🔥 Pending amount (sum of PENDING member ledger)
        pending_total = (
            db.query(func.coalesce(func.sum(MemberLedger.net_payable), 0))
            .filter(
                MemberLedger.chit_group_id == g.id,
                MemberLedger.payment_status == "PENDING"
            )
            .scalar()
        ) or 0

        result.append({
            "id": str(g.id),
            "group_name": g.group_name,
            "chit_amount": g.chit_amount,
            "duration_months": g.duration_months,
            "total_slots": g.total_slots,                 # ✅ FIXES 500 ERROR
            "lifecycle_status": g.lifecycle_status,

            # 🔥 Enriched fields for My Chits UI
            "current_month": g.current_month_no,
            "chit_type": chit_type,
            "reserve_amount": int(reserve_total),
            "dividend_earned": int(dividend_total),
            "pending_amount": int(pending_total),
        })
    logger.info(f"🔥 MY CHITS PAYLOAD: {result}")
    return result



@router.post("/{chit_group_id}/configure", summary="Configure Chit Rules")
def configure_group(
    chit_group_id: str,
    settings: ChitRuleSettingsV2,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
    ):
    group = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Chit group not found")

    try:
        final_settings = enrich_and_validate(
            settings.model_dump(),
            chit_amount=group.chit_amount,
            duration_months=group.duration_months,
            total_slots=group.total_slots
        )
    except ValueError as e:
        # 🔥 This is the key fix
        raise HTTPException(status_code=400, detail=str(e))

    group = configure_chit_group(db, chit_group_id, final_settings)

    return {
        "id": str(group.id),
        "status": group.lifecycle_status,
        "preview": final_settings.get("preview")
    }


@router.post("/{chit_group_id}/activate")
def activate_group(
    chit_group_id: str,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
    ):
    group = activate_chit_group(db, chit_group_id)
    return {
        "id": str(group.id),
        "status": group.lifecycle_status
    }


@router.post("/{chit_group_id}/start")
def start_group(
    chit_group_id: str,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
    ):
    group = start_chit_group(db, chit_group_id)
    return {
        "id": str(group.id),
        "status": group.lifecycle_status
    }


@router.post("/{chit_group_id}/close")
def close_group(
    chit_group_id: str,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
    ):
    group = close_chit_group(db, chit_group_id)
    return {
        "id": str(group.id),
        "status": group.lifecycle_status
    }

@router.post("/preview-rules", summary="Preview chit rules without saving")
def preview_rules(
    settings: ChitRuleSettingsV2,
    chit_amount: int,
    duration_months: int,
    total_slots: int,
    current_user = Depends(get_current_user)
    ):
    final_settings = enrich_and_validate(
        settings.model_dump(),
        chit_amount=chit_amount,
        duration_months=duration_months,
        total_slots=total_slots
    )

    return {
        "chit_type": final_settings["chit_type"],
        "preview": final_settings["preview"]
    }

@router.post("/{chit_group_id}/preview-rules")
def preview_rules(
    chit_group_id: str,
    settings: ChitRuleSettingsV2,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
    ):
    group = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not group:
        return {"error": "Chit group not found"}

    # Only simulate, do not save
    final_settings = enrich_and_validate(
        settings.model_dump(),
        chit_amount=group.chit_amount,
        duration_months=group.duration_months,
        total_slots=group.total_slots
    )

    return {
        "preview": final_settings["preview"]
    }

@router.post("/{chit_group_id}/close-month", response_model=CloseMonthResponse)
def close_month(
    chit_group_id: UUID,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
    ):
    try:
        return close_chit_month(db, chit_group_id)
    except Exception as e:
        print("🔥 CLOSE MONTH ERROR:", str(e))   # 👈 add this
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/{chit_group_id}/reserve")
def get_chit_reserve(chit_group_id: str, db: Session = Depends(get_db)):
    return get_reserve_summary(db, chit_group_id)

@router.get("/{chit_group_id}/summary")
def chit_summary(chit_group_id: UUID, db: Session = Depends(get_db)):
    chit = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    
    if not chit:
        raise HTTPException(status_code=404, detail="Chit group not found")

    # 1️⃣ WhatsApp link
    whatsapp_link = db.query(GroupLink).filter(
        GroupLink.chit_group_id == chit_group_id,
        GroupLink.platform == "whatsapp",
        GroupLink.is_active == True
    ).first()

    # 2️⃣ Settings
    settings = chit.settings or {}

    # 3️⃣ Monthly due (base installment)
    monthly_due = 0
    if "monthly_due" in settings:
        monthly_due = settings["monthly_due"].get("amount", 0)

    # 4️⃣ Current month started?
    next_month_no = chit.current_month_no + 1
    is_started = db.query(MemberLedger).filter(
        MemberLedger.chit_group_id == chit.id,
        MemberLedger.month_no == next_month_no,
    ).first() is not None

    # 5️⃣ Chit type
    chit_type = settings.get("chit_type", "KULUKAL")

    # 6️⃣ 🔥 Dividend total (ONLY for AUCTION)
    dividend_total = 0
    if chit_type == "AUCTION":
        dividend_total = (
            db.query(func.coalesce(func.sum(AuctionRound.dividend_per_member), 0))
            .filter(
                AuctionRound.chit_group_id == chit_group_id,
                AuctionRound.status.in_(["WINNER_DECIDED", "CLOSED"])   
            )
            .scalar()
        ) or 0

    # 7️⃣ 🔥 Schedule info (informational only)
    next_run_date = chit.next_run_date.isoformat() if chit.next_run_date else None
    schedule_rule = settings.get("schedule_rule")   # ✅ THIS FIXES "Not Configured"
    print("🔥 WHATSAPP LINK FROM DB:", whatsapp_link.link_url if whatsapp_link else None)
    return {
        "group_name": chit.group_name,
        "chit_amount": chit.chit_amount,
        "duration_months": chit.duration_months,
        "total_slots": chit.total_slots,
        "current_month": chit.current_month_no,
        "status": chit.lifecycle_status,

        "installment_amount": monthly_due,
        "is_current_month_started": is_started,

        "chit_type": chit_type,
        "dividend_total": int(dividend_total),   # total dividend distributed so far

        # 🔥 Schedule (for Schedule tab + header line)
        "next_run_date": next_run_date,
        "schedule_rule": schedule_rule,

        # 🔥 WhatsApp integration
        "whatsapp_group_link": whatsapp_link.link_url if whatsapp_link else None,

        # placeholders (future dashboard calc)
        "total_paid": 0,
        "total_due": 0,
    }



@router.post("/{chit_group_id}/start-month")
def start_month(
    chit_group_id: UUID,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return start_chit_month(db, chit_group_id)

@router.get("/{chit_group_id}/current-month-started")
def is_month_started(chit_group_id: UUID, db: Session = Depends(get_db)):
    chit = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    next_month_no = chit.current_month_no + 1

    exists = db.query(MemberLedger).filter(
        MemberLedger.chit_group_id == chit.id,
        MemberLedger.month_no == next_month_no,
    ).first()

    return {
        "month_no": next_month_no,
        "started": bool(exists)
    }

@router.post("/{chit_group_id}/update-next-run-date")
def update_next_run_date(chit_group_id: UUID, payload: dict, db: Session = Depends(get_db)):
    chit = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not chit:
        raise HTTPException(status_code=404, detail="Chit group not found")

    chit.next_run_date = datetime.fromisoformat(payload["next_run_date"]).date()
    db.add(chit)
    db.commit()

    return {"status": "ok", "next_run_date": chit.next_run_date}


@router.post("/preview-curve")
def preview_kulukal_curve(payload: dict, current_user=Depends(get_current_user)):
    chit_amount = payload.get("chit_amount")
    months = payload.get("duration_months")
    chit_type = payload.get("chit_type")
    prize_mode = payload.get("prize_mode")

    foreman_type = payload.get("foreman_type")          # FULL_MONTH / PERCENTAGE
    foreman_month = payload.get("foreman_month", 0)     # 0 = ANY, else FIXED month

    if not chit_amount or not months or months < 2:
        return {
            "preview": [],
            "start_amount": None,
            "end_amount": None,
            "note": "Invalid chit amount or duration"
        }

    if chit_type != "KULUKAL" or prize_mode != "CURVE":
        return {
            "preview": [],
            "start_amount": None,
            "end_amount": None
        }

    curve = generate_kulukal_booklet_curve(
        chit_amount=chit_amount,
        months=months
    )

    if not curve:
        return {
            "preview": [],
            "start_amount": None,
            "end_amount": None,
            "note": "Curve generation returned empty"
        }

    preview_rows = []
    curve_index = 0

    for month_no in range(1, months + 1):

        # 🔥 Foreman full-month payout (FIXED)
        if foreman_type == "FULL_MONTH" and foreman_month == month_no:
            preview_rows.append({
                "month": month_no,
                "type": "FOREMAN",
                "payout": chit_amount
            })
            continue

        # 🔥 Normal member prize from curve
        if curve_index < len(curve):
            preview_rows.append({
                "month": month_no,
                "type": "MEMBER",
                "payout": curve[curve_index]
            })
            curve_index += 1
        else:
            # Safety fallback (shouldn't normally happen)
            preview_rows.append({
                "month": month_no,
                "type": "MEMBER",
                "payout": curve[-1]
            })

    return {
        "preview": preview_rows,
        "start_amount": curve[0],
        "end_amount": curve[-1]
    }


