from sqlalchemy.orm import Session
from datetime import datetime, date
from sqlalchemy import func
from app.models.chit_group_model import ChitGroup
from app.models.chit_member_model import ChitMember
from app.models.member_ledger_model import MemberLedger
from app.models.auction_round_model import AuctionRound
from app.models.reserve_ledger_model import ReserveLedger
from app.services.subscription_service import (
    preview_upgrade
)
from app.core.chit_state_engine import mark_configured, mark_active, mark_running, mark_closed
from app.schemas.chit_rule_v2_schema import ChitRuleSettingsV2
from app.services.chit_rule_service import (enrich_and_validate, calculate_next_run_date)
from uuid import UUID
print("ReserveLedger model loaded:", ReserveLedger)

def preview_chit_group_create(db: Session, admin_id: str):
    current_groups = get_active_group_count(db, admin_id)
    projected_groups = current_groups + 1

    result = preview_upgrade(db, admin_id, projected_groups)

    if result["upgrade_required"]:
        return {
            "allowed": False,
            "upgrade_required": True,
            "message": "Subscription upgrade required",
            "preview": result
        }

    return {
        "allowed": True,
        "upgrade_required": False,
        "message": "You can create new chit group",
        "preview": None
    }


def create_chit_group(db: Session, admin_id: str, data):
    """
    Step 1: Create in DRAFT state (basic info only)
    """

    #print("DEBUG service payload:", data)
    #print("DEBUG total_slots:", getattr(data, "total_slots", "NO_SLOT"))
    #print("DEBUG total_members:", getattr(data, "total_members", "NO_MEMBERS"))

    group = ChitGroup(
        admin_id=admin_id,
        group_name=data.group_name,
        chit_amount=data.chit_amount,
        total_slots=data.total_slots,
        duration_months=data.duration_months,
        settings={},              # empty initially
        lifecycle_status="DRAFT"
    )
    db.add(group)
    db.commit()
    db.refresh(group)
    return group


def configure_chit_group(db: Session, chit_group_id: str, settings: dict):
    group = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not group:
        return None

    final_settings = enrich_and_validate(
        settings,
        chit_amount=group.chit_amount,
        duration_months=group.duration_months,
        total_slots=group.total_slots
    )

    clean_settings = final_settings.copy()
    clean_settings.pop("preview", None)

    rule_obj = ChitRuleSettingsV2(**clean_settings)
    group.settings = rule_obj.model_dump()

    # ✅ Allow idempotent save
    if group.lifecycle_status == "DRAFT":
        mark_configured(group)
        mark_active(group)   # 🔥 auto-activate after config

    db.commit()
    db.refresh(group)
    return group





def activate_chit_group(db: Session, chit_group_id):
    """
    Step 3: Members added → move to ACTIVE
    """
    group = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not group:
        return None

    mark_active(group)

    db.commit()
    db.refresh(group)
    return group


def start_chit_group(db: Session, chit_group_id):
    """
    Step 4: First auction opened → move to RUNNING
    """
    group = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not group:
        return None

    mark_running(group)

    db.commit()
    db.refresh(group)
    return group


def close_chit_month(db: Session, chit_group_id: UUID):
    chit_group = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not chit_group:
        raise Exception("Chit group not found")

    current_month = chit_group.current_month_no + 1

    settings = chit_group.settings or {}

    unpaid = (
        db.query(MemberLedger)
        .filter(
            MemberLedger.chit_group_id == chit_group_id,
            MemberLedger.month_no == current_month,
            MemberLedger.entry_type == "MONTHLY",
            MemberLedger.payment_status != "PAID",
        )
        .count()
    )

    if unpaid > 0:
        raise Exception("Cannot close month: payments pending")

    auctions = (
        db.query(AuctionRound)
        .filter(
            AuctionRound.chit_group_id == chit_group_id,
            AuctionRound.month_no == current_month,
        )
        .all()
    )

    for auction in auctions:
        if not auction.is_auto and auction.winning_member_id is None:
            raise Exception(f"Cannot close month: auction round {auction.round_no} winner not decided")
        auction.status = "CLOSED"
        db.add(auction)

    chit_group.current_month_no += 1

    schedule_rule = settings.get("schedule_rule")
    if schedule_rule:
        chit_group.next_run_date = calculate_next_run_date(date.today(), schedule_rule)

    db.add(chit_group)
    db.commit()
    db.refresh(chit_group)

    return {
        "chit_group_id": str(chit_group.id),
        "closed_month_no": current_month,
        "new_current_month_no": chit_group.current_month_no,
        "auction_rounds_closed": len(auctions),
        "next_run_date": chit_group.next_run_date.isoformat() if chit_group.next_run_date else None,
    }

def generate_kulukal_booklet_curve(chit_amount: int, months: int):
    """
    Month 1 = Company
    Month 2..N = Prize curve based on temple booklet pattern (scaled)
    Base template is for 1,00,000 chit.
    """
    if not chit_amount or not months or months < 2:
        return []

    
    base = chit_amount / 100000

    # Starting prize (Month 2)
    start = int(90000 * base)

    increments = [
        1000,                 # Month 3
        *([500] * 8),         # Month 4–11
        *([1000] * 3),        # Month 12–14
        2500,                 # 15
        3000,                 # 16
        3500,                 # 17
        4000,                 # 18
        4000,                 # 19
        5000,                 # 20
        5000                  # 21
    ]

    increments = [int(i * base) for i in increments]

    curve = [start]
    for inc in increments:
        curve.append(curve[-1] + inc)

    # Trim or extend if months differ
    return curve[:months - 1]

def generate_flat_curve(prize: int, months: int):
    return [prize] * (months - 1)

def build_prize_rule_for_kulukal(chit_amount: int, months: int):
    curve = generate_kulukal_booklet_curve(chit_amount=chit_amount, months=months)

    start_amount = curve[0]
    end_amount = curve[-1]

    return {
        "mode": "CURVE",
        "curve_type": "BOOKLET",
        "start_amount": start_amount,
        "end_amount": end_amount
    }

def start_chit_month(db: Session, chit_group_id: UUID):
    chit = db.query(ChitGroup).filter(ChitGroup.id == chit_group_id).first()
    if not chit:
        raise Exception("Chit not found")

    if chit.lifecycle_status != "RUNNING":
        raise Exception("Chit is not running")

    next_month_no = chit.current_month_no + 1

    # 🔒 Guard 1: Prevent duplicate month start
    exists = db.query(MemberLedger).filter(
        MemberLedger.chit_group_id == chit.id,
        MemberLedger.month_no == next_month_no,
        MemberLedger.entry_type == "MONTHLY",
    ).first()

    if exists:
        return {
            "month_no": next_month_no,
            "status": "ALREADY_STARTED",
        }

    # 🔒 Load active members eligible for this month
    members = (
        db.query(ChitMember)
        .filter(
            ChitMember.chit_group_id == chit.id,
            ChitMember.joined_month <= next_month_no,
            ChitMember.status == "ACTIVE",
        )
        .all()
    )

    # 🔒 Guard 2: No members
    if not members:
        raise Exception("Cannot start month: No members joined yet")

    monthly_due = chit.settings["monthly_due"]["amount"]
    chit_amount = chit.chit_amount

    # 🔒 Guard 3: Minimum slots required
    min_slots_required = int(chit_amount / monthly_due)
    active_slots = len(members)

    if active_slots < min_slots_required:
        raise Exception(
            f"Cannot start month: Minimum {min_slots_required} slots required, "
            f"but only {active_slots} slots available"
        )

    expected_collection = 0

    # ✅ Create MONTHLY ledger entries (slot-level) with catch-up for late joiners
    for m in members:
        # 🔥 Detect late joiner
        is_new_joiner = (m.joined_month == next_month_no)

        catchup_amount = 0
        if is_new_joiner:
            missed_months = next_month_no - 1   # months already completed
            catchup_amount = missed_months * monthly_due

        net_payable = monthly_due + catchup_amount
        expected_collection += net_payable

        db.add(
            MemberLedger(
                chit_group_id=chit.id,
                member_id=m.id,              # each row = one slot
                month_no=next_month_no,
                installment_amount=monthly_due,
                dividend_amount=0,
                net_payable=net_payable,     # 🔥 includes catch-up
                payment_status="PENDING",
                entry_type="MONTHLY",
            )
        )

    db.commit()

    return {
        "month_no": next_month_no,
        "status": "STARTED",
        "members": active_slots,
        "min_required": min_slots_required,
        "expected_collection": expected_collection,  # 🔥 accurate incl. catch-up
    }

def get_active_group_count(db: Session, admin_id):
    return db.query(ChitGroup).filter(
        ChitGroup.admin_id == admin_id,
        ChitGroup.lifecycle_status == "ACTIVE"
    ).count()

def close_chit_group(db: Session, chit_group_id: UUID):
    chit_group = (
        db.query(ChitGroup)
        .filter(ChitGroup.id == chit_group_id)
        .first()
    )

    if not chit_group:
        raise ChitStateError("Chit group not found")

    if chit_group.lifecycle_status != "RUNNING":
        raise ChitStateError("Only RUNNING chit can be closed")

    # 🔒 Guard: All months must be completed
    if chit_group.current_month_no < chit_group.duration_months:
        raise ChitStateError(
            f"Cannot close chit. Month {chit_group.current_month_no}/{chit_group.duration_months} not completed."
        )

    # ✅ Use your existing state engine helper
    mark_closed(chit_group)

    db.commit()
    db.refresh(chit_group)

    return chit_group

