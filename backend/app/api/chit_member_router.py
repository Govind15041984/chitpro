from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.database import SessionLocal
from app.core.security import get_current_user
from app.models.chit_member_model import ChitMember
from app.models.chit_group_model import ChitGroup
from app.models.member_ledger_model import MemberLedger
from app.schemas.chit_member_schema import (
    ChitMemberCreateRequest,
    ChitMemberListResponse,
    ChitMemberResponse,
    ChitMemberMultiCreateRequest
)
from app.services.chit_member_service import (
    add_member,
    list_members,
    search_eligible_members,
    add_member_with_catchup,
    add_slots_with_catchup
)

router = APIRouter(tags=["Chit Members"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# -------------------------
# BASIC ADD (NO CATCHUP)
# -------------------------
@router.post("/{chit_group_id}", response_model=ChitMemberResponse)
def create_member(
    chit_group_id: UUID,
    data: ChitMemberCreateRequest,
    db: Session = Depends(get_db)
):
    member = add_member(
        db,
        chit_group_id,
        data.name,
        data.mobile_number,
        data.member_no
    )
    return member


# -------------------------
# LIST MEMBERS
# -------------------------
@router.get("/{chit_group_id}")
def get_members(chit_group_id: UUID, db: Session = Depends(get_db)):
    return list_members(db, chit_group_id)


# -------------------------
# SEARCH ELIGIBLE MEMBERS
# -------------------------
@router.get("/{chit_group_id}/search")
def search_members(
    chit_group_id: UUID,
    q: str,
    month_no: int,   # 🔥 pass current auction month
    db: Session = Depends(get_db)
):
    members = search_eligible_members(db, chit_group_id, month_no, q)
    return [
        {
            "id": str(m.id),
            "slot_no": m.member_no,
            "name": m.name
        }
        for m in members
    ]


# -------------------------
# ADD MEMBER WITH CATCH-UP
# -------------------------
@router.post("/{chit_group_id}/with-catchup", response_model=ChitMemberResponse)
def create_member_with_catchup(
    chit_group_id: UUID,
    data: ChitMemberCreateRequest,
    db: Session = Depends(get_db),
):
    member = add_member_with_catchup(
        db=db,
        chit_group_id=chit_group_id,
        name=data.name,
        mobile_number=data.mobile_number,
    )
    return member


# -------------------------
# ADD MULTIPLE SLOTS
# -------------------------
@router.post("/{chit_group_id}/slots")
def add_slots(
    chit_group_id: UUID,
    data: ChitMemberMultiCreateRequest,
    db: Session = Depends(get_db),
):
    members = add_slots_with_catchup(
        db=db,
        chit_group_id=chit_group_id,
        name=data.name,
        mobile_number=data.mobile_number,
        slot_count=data.slot_count,
    )

    return {
        "slots_added": len(members),
        "member_nos": [m.member_no for m in members],
    }


# -------------------------
# MEMBER SLOT SUMMARY
# -------------------------
@router.get("/{chit_group_id}/summary")
def member_slot_summary(
    chit_group_id: UUID,
    db: Session = Depends(get_db),
):
    members = (
        db.query(ChitMember)
        .filter(ChitMember.chit_group_id == chit_group_id)
        .order_by(ChitMember.member_no)
        .all()
    )

    return [
        {
            "slot_no": m.member_no,
            "name": m.name,
            "joined_month": m.joined_month,
            "status": m.status,
        }
        for m in members
    ]

# --------------------------------------------------
# 🔁 TRANSFER SLOT
# --------------------------------------------------
@router.post("/{chit_group_id}/slots/{slot_id}/transfer")
def transfer_slot(
    chit_group_id: UUID,
    slot_id: UUID,
    payload: dict,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    chit = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not chit:
        raise HTTPException(404, "Chit group not found")

    # 🔒 Month lock: block if current month already started
    next_month_no = chit.current_month_no + 1
    month_started = db.query(MemberLedger.id).filter(
        MemberLedger.chit_group_id == chit_group_id,
        MemberLedger.month_no == next_month_no,
    ).first()
    if month_started:
        raise HTTPException(400, "Month already started. Slot changes are locked.")

    slot = db.query(ChitMember).filter(
        ChitMember.id == slot_id,
        ChitMember.chit_group_id == chit_group_id,
    ).first()
    if not slot:
        raise HTTPException(404, "Slot not found")

    # ❌ Prized slot cannot be transferred
    if slot.status == "PRIZED":
        raise HTTPException(400, "Prized slot cannot be transferred")

    name = payload.get("name")
    mobile = payload.get("mobile_number")

    if not name:
        raise HTTPException(400, "New member name is required")

    # ✅ Transfer ownership (slot stays same)
    slot.name = name
    slot.mobile_number = mobile

    db.commit()
    db.refresh(slot)

    return {
        "slot_id": str(slot.id),
        "slot_no": slot.member_no,
        "name": slot.name,
        "mobile_number": slot.mobile_number,
    }


# --------------------------------------------------
# 🗑 DELETE SLOT (Mistake Correction Only)
# --------------------------------------------------
@router.delete("/{chit_group_id}/slots/{slot_id}")
def delete_slot(
    chit_group_id: UUID,
    slot_id: UUID,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    chit = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not chit:
        raise HTTPException(404, "Chit group not found")

    # 🔒 Month lock
    next_month_no = chit.current_month_no + 1
    month_started = db.query(MemberLedger.id).filter(
        MemberLedger.chit_group_id == chit_group_id,
        MemberLedger.month_no == next_month_no,
    ).first()
    if month_started:
        raise HTTPException(400, "Month already started. Slot changes are locked.")

    slot = db.query(ChitMember).filter(
        ChitMember.id == slot_id,
        ChitMember.chit_group_id == chit_group_id,
    ).first()
    if not slot:
        raise HTTPException(404, "Slot not found")

    # ❌ Prized slot cannot be deleted
    if slot.status == "PRIZED":
        raise HTTPException(400, "Prized slot cannot be deleted")

    # ❌ If any ledger exists for this slot → cannot delete
    ledger_exists = db.query(MemberLedger.id).filter(
        MemberLedger.member_id == slot.id
    ).first()
    if ledger_exists:
        raise HTTPException(400, "Slot has ledger history. Cannot delete.")

    # ❌ If slot already effective (joined_month <= current_month_no)
    if slot.joined_month <= chit.current_month_no:
        raise HTTPException(400, "Slot already active. Cannot delete.")

    db.delete(slot)
    db.commit()

    return {"status": "DELETED"}