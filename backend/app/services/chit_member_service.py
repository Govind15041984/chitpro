from sqlalchemy.orm import Session
from uuid import UUID
from app.models.chit_member_model import ChitMember
from app.models.member_ledger_model import MemberLedger
from app.models.chit_group_model import ChitGroup
from app.models.auction_round_model import AuctionRound
from sqlalchemy import or_
from sqlalchemy.sql import cast
from sqlalchemy.types import String
from sqlalchemy.exc import SQLAlchemyError
from app.services.chit_member_helpers_service import (
    get_next_member_no,
    assert_can_add_slot,
)
from sqlalchemy.orm import aliased


def add_member(db: Session, chit_group_id, name: str, mobile_number: str | None, member_no: int):
    member = ChitMember(
        chit_group_id=chit_group_id,
        name=name,
        mobile_number=mobile_number,
        member_no=member_no
    )
    db.add(member)
    db.commit()
    db.refresh(member)
    return member



def list_members(db: Session, chit_group_id: UUID):
    rows = (
        db.query(
            ChitMember,
            AuctionRound.month_no.label("prize_month"),
            AuctionRound.payout_amount.label("payout_amount"),
        )
        .outerjoin(
            AuctionRound,
            (AuctionRound.winning_member_id == ChitMember.id)
            & (AuctionRound.chit_group_id == chit_group_id)
        )
        .filter(ChitMember.chit_group_id == chit_group_id)
        .order_by(ChitMember.member_no)
        .all()
    )

    result = []
    for member, prize_month, payout_amount in rows:
        payload = {
            "id": str(member.id),
            "member_no": member.member_no,
            "name": member.name,
            "mobile_number": member.mobile_number,
            "status": member.status,
            "joined_month": member.joined_month,
            "has_won": prize_month is not None,
            "prize_month": prize_month,
            "payout_amount": payout_amount,
        }
        result.append(payload)

    print("📦 MEMBERS PAYLOAD:", result)
    return result   # ✅ plain list




def mark_member_prized(db: Session, member_id):
    member = db.query(ChitMember).filter(ChitMember.id == member_id).first()
    if not member:
        return None

    member.status = "PRIZED"
    db.commit()
    db.refresh(member)
    return member

def search_eligible_members(db: Session, chit_group_id: UUID, month_no: int, query: str):
    # 🔥 Get all winners so far in this chit
    won_ids = (
        db.query(AuctionRound.winning_member_id)
        .filter(
            AuctionRound.chit_group_id == chit_group_id,
            AuctionRound.winning_member_id.isnot(None),
        )
        .subquery()
    )

    return (
        db.query(ChitMember)
        .filter(
            ChitMember.chit_group_id == chit_group_id,
            ChitMember.status == "ACTIVE",
            ChitMember.joined_month <= month_no,     # joined before or in this month
            ~ChitMember.id.in_(won_ids),             # 🔥 exclude past winners
            or_(
                ChitMember.name.ilike(f"%{query}%"),
                cast(ChitMember.member_no, String).ilike(f"%{query}%"),
            ),
        )
        .order_by(ChitMember.member_no)
        .all()
    )


def add_member_with_catchup(
    db: Session,
    chit_group_id,
    name: str,
    mobile_number: str | None,
):
    chit_group = (
        db.query(ChitGroup)
        .filter(ChitGroup.id == chit_group_id)
        .first()
    )

    if not chit_group:
        raise Exception("Chit group not found")

    if chit_group.lifecycle_status != "RUNNING":
        raise Exception("Members can be added only to RUNNING chit")

    next_month = chit_group.current_month_no + 1
    if not next_month or next_month <= 0:
        next_month = 1

    member_no = get_next_member_no(db, chit_group_id)  # AUTO SLOT NO

    member = ChitMember(
        chit_group_id=chit_group_id,
        name=name,
        mobile_number=mobile_number,
        member_no=member_no,
        joined_month=next_month,
    )

    db.add(member)
    db.commit()
    db.refresh(member)
    return member

def add_slots_with_catchup(
    db: Session,
    chit_group_id,
    name,
    mobile_number,
    slot_count: int,
):
    chit = assert_can_add_slot(db, chit_group_id)

    next_month = chit.current_month_no + 1
    if not next_month or next_month <= 0:
        next_month = 1

    created_members = []

    for _ in range(slot_count):
        member_no = get_next_member_no(db, chit_group_id)

        member = ChitMember(
            chit_group_id=chit_group_id,
            name=name,
            mobile_number=mobile_number,
            member_no=member_no,
            joined_month=next_month,
        )
        db.add(member)
        db.flush()

        created_members.append(member)

    db.commit()
    return created_members



    
