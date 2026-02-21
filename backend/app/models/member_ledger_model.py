import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base


class MemberLedger(Base):
    __tablename__ = "member_ledger"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chit_group_id = Column(UUID(as_uuid=True), ForeignKey("chit_groups.id"), nullable=False)
    member_id = Column(UUID(as_uuid=True), ForeignKey("chit_members.id"), nullable=False)

    month_no = Column(Integer, nullable=False)

    installment_amount = Column(Integer, nullable=False)
    dividend_amount = Column(Integer, nullable=False)
    net_payable = Column(Integer, nullable=False)

    entry_type = Column(String(20), default="MONTHLY")  # MONTHLY, PRIZE, ADJUSTMENT
    payment_status = Column(String(20), default="PENDING")  
    # PENDING, PAID

    paid_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
