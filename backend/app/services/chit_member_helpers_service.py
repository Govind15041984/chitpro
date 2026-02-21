from sqlalchemy import func
from sqlalchemy.orm import Session
from app.models.chit_member_model import ChitMember
from app.models.chit_group_model import ChitGroup
from uuid import UUID


def get_next_member_no(db: Session, chit_group_id):
    max_no = (
        db.query(func.max(ChitMember.member_no))
        .filter(ChitMember.chit_group_id == chit_group_id)
        .scalar()
    )
    return (max_no or 0) + 1


def assert_can_add_slot(db: Session, chit_group_id: UUID):
    chit = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()

    if not chit:
        raise HTTPException(status_code=404, detail="Chit group not found")

    if chit.lifecycle_status != "RUNNING":
        raise HTTPException(
            status_code=400,
            detail="Slots can be added only when chit is RUNNING"
        )

    current_slots = db.query(ChitMember).filter(
        ChitMember.chit_group_id == chit_group_id
    ).count()

    if current_slots >= chit.total_slots:
        raise HTTPException(
            status_code=400,
            detail="All slots are already filled"
        )

    return chit
