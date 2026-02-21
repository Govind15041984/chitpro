import uuid
from datetime import datetime

from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base  


class ReserveLedger(Base):
    __tablename__ = "reserve_ledger"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    chit_group_id = Column(
        UUID(as_uuid=True),
        ForeignKey("chit_groups.id"),
        nullable=False
    )

    month_no = Column(Integer, nullable=False)

    source = Column(String(50), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow)
