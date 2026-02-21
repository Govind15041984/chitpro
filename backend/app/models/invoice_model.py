import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base

class Invoice(Base):
    __tablename__ = "invoices"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    admin_id = Column(UUID(as_uuid=True), ForeignKey("admins.id"), nullable=False)

    slab_code = Column(String(20), nullable=False)
    amount = Column(Integer, nullable=False)

    billing_month = Column(String(7), nullable=False)  # e.g. "2026-01"

    status = Column(String(20), default="CREATED")  
    # CREATED, PAID, FAILED

    razorpay_payment_id = Column(String(100), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    paid_at = Column(DateTime, nullable=True)
