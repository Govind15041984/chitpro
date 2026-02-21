from sqlalchemy import func
from app.models.reserve_ledger_model import ReserveLedger


def get_reserve_summary(db, chit_group_id):
    rows = (
        db.query(
            ReserveLedger.source,
            func.sum(ReserveLedger.amount).label("total")
        )
        .filter(ReserveLedger.chit_group_id == chit_group_id)
        .group_by(ReserveLedger.source)
        .all()
    )

    breakdown = {row.source: float(row.total) for row in rows}
    total = sum(breakdown.values())

    return {
        "total": total,
        "breakdown": breakdown
    }
