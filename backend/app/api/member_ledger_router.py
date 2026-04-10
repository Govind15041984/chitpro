from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from uuid import UUID
from datetime import datetime
from app.core.database import SessionLocal
from app.schemas.member_ledger_schema import MemberLedgerListResponse,MonthlyCollectionResponse
from app.models.member_ledger_model import MemberLedger
from app.models.chit_member_model import ChitMember
from app.models.chit_payment_audit_model import PaymentAudit
from app.models.auction_round_model import AuctionRound
from app.models.chit_group_model import ChitGroup
from sqlalchemy import func, case
from app.core.security import get_current_user

router = APIRouter(tags=["Member Ledger"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/member/{member_id}")
def get_member_ledger(member_id: UUID, db: Session = Depends(get_db)):
    entries = db.query(MemberLedger).filter(
        MemberLedger.member_id == member_id
    ).order_by(MemberLedger.month_no).all()

    return {"entries": entries}


@router.get("/group/{chit_group_id}")
def get_group_ledger(chit_group_id: UUID, db: Session = Depends(get_db)):
    entries = db.query(MemberLedger).filter(
        MemberLedger.chit_group_id == chit_group_id
    ).order_by(MemberLedger.month_no, MemberLedger.member_id).all()

    return {"entries": entries}

@router.get("/dashboard/monthly-collection")
def get_monthly_collection(
    admin_id: str,
    db: Session = Depends(get_db),
):
    # Find the current relevant month across this admin's active groups
    current_month = (
        db.query(func.max(MemberLedger.month_no))
        .join(ChitGroup, ChitGroup.id == MemberLedger.chit_group_id)
        .filter(ChitGroup.admin_id == admin_id)
        .scalar()
    ) or 0

    # Get sum of installments for that month across all admin's groups
    total = (
        db.query(func.sum(MemberLedger.installment_amount))
        .join(ChitGroup, ChitGroup.id == MemberLedger.chit_group_id)
        .filter(
            ChitGroup.admin_id == admin_id,
            MemberLedger.month_no == current_month,
            MemberLedger.payment_status == "PAID" # Usually dashboard shows collected vs target
        )
        .scalar()
    ) or 0

    return {
        "month_no": current_month,
        "total_collected": total
    }

@router.get("/group/{chit_group_id}/month/{month_no}")
def get_monthly_dues(chit_group_id: UUID, month_no: int, db: Session = Depends(get_db)):
    rows = (
        db.query(
            ChitMember.mobile_number.label("person_key"),
            ChitMember.name.label("name"),
            func.count(MemberLedger.id).label("slot_count"),
            func.sum(MemberLedger.net_payable).label("total_due"),
            func.sum(
                case(
                    (MemberLedger.payment_status == "PAID", MemberLedger.net_payable),
                    else_=0
                )
            ).label("paid_amount"),
        )
        .join(ChitMember, ChitMember.id == MemberLedger.member_id)
        .filter(
            MemberLedger.chit_group_id == chit_group_id,
            MemberLedger.month_no == month_no,
        )
        .group_by(
            ChitMember.mobile_number, 
            ChitMember.name
        )
        .order_by(ChitMember.name.asc()) 
        .all()
    )

    return [
        {
            "person_key": r.person_key,     # 🔥 stable grouping key
            "name": r.name,
            "slot_count": int(r.slot_count),
            "total_due": int(r.total_due or 0),
            "paid_amount": int(r.paid_amount or 0),
            "balance": int((r.total_due or 0) - (r.paid_amount or 0)),
        }
        for r in rows
    ]



@router.post("/{ledger_id}/mark-paid")
def mark_payment_paid(
    ledger_id: UUID,
    db: Session = Depends(get_db),
    ):
    ledger = (
        db.query(MemberLedger)
        .filter(MemberLedger.id == ledger_id)
        .first()
    )

    if not ledger:
        raise Exception("Ledger entry not found")

    # 🔒 Idempotency guard
    if ledger.payment_status == "PAID":
        return {"status": "PAID"}

    # 1️⃣ Update ledger
    ledger.payment_status = "PAID"
    ledger.paid_at = datetime.utcnow()

    # 2️⃣ Write audit trail
    db.add(
        PaymentAudit(
            ledger_id=ledger.id,
            chit_group_id=ledger.chit_group_id,
            member_id=ledger.member_id,
            action="MARK_PAID",
            amount=ledger.net_payable,
            remarks="Marked as paid",
        )
    )

    db.commit()
    db.refresh(ledger)

    return {"status": "PAID"}

@router.post("/{ledger_id}/undo-paid")
def undo_payment(
    ledger_id: UUID,
    reason: str = "Correction",
    db: Session = Depends(get_db),
    ):
    ledger = db.query(MemberLedger).filter(
        MemberLedger.id == ledger_id
    ).first()

    if not ledger:
        raise Exception("Ledger not found")

    if ledger.payment_status != "PAID":
        raise Exception("Payment is not marked as PAID")

    ledger.payment_status = "PENDING"
    ledger.paid_at = None

    db.add(
        PaymentAudit(
            ledger_id=ledger.id,
            chit_group_id=ledger.chit_group_id,
            member_id=ledger.member_id,
            action="UNDO_PAID",
            amount=ledger.net_payable,
            remarks=reason,
        )
    )

    db.commit()
    return {"status": "PENDING"}

@router.get("/{ledger_id}/audit")
def get_payment_audit(
    ledger_id: UUID,
    db: Session = Depends(get_db),
):
    audits = (
        db.query(PaymentAudit)
        .filter(PaymentAudit.ledger_id == ledger_id)
        .order_by(PaymentAudit.performed_at.desc())
        .all()
    )

    return [
        {
            "action": a.action,
            "amount": a.amount,
            "at": a.performed_at,
            "remarks": a.remarks,
        }
        for a in audits
    ]

@router.post("/collect")
def collect_partial_payment(
    payload: dict,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    chit_group_id = UUID(payload["chit_group_id"])
    person_key = payload["person_key"]          # mobile number
    month_no = int(payload["month_no"])
    amount = int(payload["amount"])

    # 1️⃣ Get all unpaid slots for this person in this month
    ledgers = (
        db.query(MemberLedger)
        .join(ChitMember, ChitMember.id == MemberLedger.member_id)
        .filter(
            MemberLedger.chit_group_id == chit_group_id,
            ChitMember.mobile_number == person_key,
            MemberLedger.month_no == month_no,
            MemberLedger.payment_status != "PAID",
        )
        .order_by(MemberLedger.id.asc())
        .all()
    )

    if not ledgers:
        raise HTTPException(400, "No pending dues for this member")

    remaining = amount
    total_applied = 0

    for l in ledgers:
        if remaining <= 0:
            break

        l.payment_status = "PAID"
        l.paid_at = datetime.utcnow()
        remaining -= l.net_payable
        total_applied += l.net_payable

        db.add(PaymentAudit(
            ledger_id=l.id,
            chit_group_id=chit_group_id,
            member_id=l.member_id,
            action="PARTIAL_COLLECT",
            amount=l.net_payable,
            remarks="Collected via partial payment",
            performed_at=datetime.utcnow(),
            performed_by=current_user["id"],
        ))

    # =====================================================
    # 🔥 FIX: Always update ROUND 1 total_collection only
    # =====================================================
    auction = (
        db.query(AuctionRound)
        .filter(
            AuctionRound.chit_group_id == chit_group_id,
            AuctionRound.month_no == month_no,
            AuctionRound.round_no == 1,          # ✅ ONLY ROUND 1
            AuctionRound.status != "CLOSED",
        )
        .first()
    )

    if auction:
        auction.total_collection = (auction.total_collection or 0) + total_applied
        db.add(auction)
        db.flush()

    db.commit()

    if auction:
        db.refresh(auction)

    result = {
        "applied_amount": total_applied,
        "unadjusted_amount": remaining,
        "total_collection": auction.total_collection if auction else 0,
    }

    print("🔥 COLLECT DEBUG:", result)
    return result

@router.get("/person/{chit_group_id}/{person_key}")
def get_person_ledger_all_months(
    chit_group_id: UUID,
    person_key: str,
    db: Session = Depends(get_db),
):
    rows = (
        db.query(
            MemberLedger.month_no.label("month_no"),
            func.count(MemberLedger.id).label("slot_count"),           # 🔥 NEW
            func.sum(MemberLedger.net_payable).label("net_payable"),
            func.sum(
                case(
                    (MemberLedger.payment_status == "PAID", MemberLedger.net_payable),
                    else_=0
                )
            ).label("paid_amount"),
            func.max(MemberLedger.paid_at).label("last_paid_at"),      # 🔥 NEW
        )
        .join(ChitMember, ChitMember.id == MemberLedger.member_id)
        .filter(
            MemberLedger.chit_group_id == chit_group_id,
            ChitMember.mobile_number == person_key,
        )
        .group_by(MemberLedger.month_no)
        .order_by(MemberLedger.month_no.desc())   # since you fixed backend sorting
        .all()
    )

    return [
        {
            "month_no": int(r.month_no),
            "slot_count": int(r.slot_count or 0),
            "net_payable": int(r.net_payable or 0),
            "paid_amount": int(r.paid_amount or 0),
            "balance": int((r.net_payable or 0) - (r.paid_amount or 0)),
            "last_paid_at": r.last_paid_at.isoformat() if r.last_paid_at else None,
        }
        for r in rows
    ]


@router.post("/collect-batch")
def collect_batch_payment(payload: dict, db: Session = Depends(get_db)):
    chit_group_id = UUID(payload["chit_group_id"])
    person_keys = payload["person_keys"]
    month_no = int(payload["month_no"])

    # 1. First, get the IDs of the members based on the mobile numbers (person_keys)
    member_ids = (
        db.query(ChitMember.id)
        .filter(ChitMember.mobile_number.in_(person_keys))
        .all()
    )
    # Flatten the list of tuples [(id1,), (id2,)] into [id1, id2]
    id_list = [m[0] for m in member_ids]

    if not id_list:
        return {"status": "SUCCESS", "message": "No members found"}

    # 2. Perform the update on MemberLedger using the ID list
    # This avoids the JOIN error
    db.query(MemberLedger).filter(
        MemberLedger.chit_group_id == chit_group_id,
        MemberLedger.member_id.in_(id_list),
        MemberLedger.month_no == month_no,
        MemberLedger.payment_status != "PAID"
    ).update({
        "payment_status": "PAID",
        "paid_at": datetime.utcnow()
    }, synchronize_session=False)

    # 3. Update the Auction total collection
    total_paid = db.query(func.sum(MemberLedger.net_payable)).filter(
        MemberLedger.chit_group_id == chit_group_id,
        MemberLedger.month_no == month_no,
        MemberLedger.payment_status == "PAID"
    ).scalar() or 0

    db.query(AuctionRound).filter(
        AuctionRound.chit_group_id == chit_group_id,
        AuctionRound.month_no == month_no,
        AuctionRound.round_no == 1
    ).update({"total_collection": total_paid}, synchronize_session=False)

    db.commit()
    return {"status": "SUCCESS"}




