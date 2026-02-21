import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base

class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    admin_id = Column(UUID(as_uuid=True), ForeignKey("admins.id"), nullable=False)
    
    # ADDED: Explicit Foreign Key to the SubscriptionPlan table
    # This ensures slab_code MUST exist in the plans table.
    slab_code = Column(String(50), ForeignKey("subscription_plans.slab_code"), nullable=False)  
    
    razorpay_order_id = Column(String(100), nullable=True)
    razorpay_payment_id = Column(String(100), nullable=True)

    status = Column(String(20), default="CREATED") 
    
    cycle_start = Column(DateTime, default=datetime.utcnow)
    cycle_end = Column(DateTime, nullable=True) 
    created_at = Column(DateTime, default=datetime.utcnow)