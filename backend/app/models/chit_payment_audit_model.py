from app.core.database import Base
import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID

class PaymentAudit(Base):
    __tablename__ = "chit_payment_audit"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    ledger_id = Column(UUID(as_uuid=True), ForeignKey("member_ledger.id"), nullable=False)
    chit_group_id = Column(UUID(as_uuid=True), ForeignKey("chit_groups.id"), nullable=False)
    member_id = Column(UUID(as_uuid=True), ForeignKey("chit_members.id"), nullable=False)

    action = Column(String(20), nullable=False)
    # MARK_PAID, UNDO_PAID

    amount = Column(Integer, nullable=False)

    performed_by = Column(UUID(as_uuid=True), nullable=True)  # admin id
    performed_at = Column(DateTime, default=datetime.utcnow)

    remarks = Column(String(255), nullable=True)
