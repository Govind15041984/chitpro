from sqlalchemy.orm import Session
from app.models.member_ledger_model import MemberLedger
from app.models.chit_member_model import ChitMember


def generate_monthly_ledger(
    db: Session,
    chit_group_id,
    month_no: int,
    installment_amount: int,
    dividend_per_member: int,
    members,   # ✅ pass eligible members
):
    ledger_entries = []

    for m in members:
        net_payable = installment_amount - dividend_per_member

        entry = MemberLedger(
            chit_group_id=chit_group_id,
            member_id=m.id,
            month_no=month_no,
            installment_amount=installment_amount,
            dividend_amount=dividend_per_member,
            net_payable=net_payable,
            entry_type="MONTHLY",
            payment_status="PENDING",
        )
        db.add(entry)
        ledger_entries.append(entry)

    db.commit()
    return ledger_entries



def generate_prize_entry(
    db: Session,
    chit_group_id,
    member_id,
    month_no: int,
    payout_amount: int
):
    prize_entry = MemberLedger(
        chit_group_id=chit_group_id,
        member_id=member_id,
        month_no=month_no,
        installment_amount=0,
        dividend_amount=0,
        net_payable=-payout_amount,  # negative means credit to member
        entry_type="PRIZE"
    )
    db.add(prize_entry)
    db.commit()
    db.refresh(prize_entry)
    return prize_entry
