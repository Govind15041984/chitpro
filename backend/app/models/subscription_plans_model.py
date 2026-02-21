import uuid
from sqlalchemy import Column, String, Integer, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
from app.core.database import Base

class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Names: FREE, BASIC_199, STANDARD_499, PREMIUM_1499
    slab_code = Column(String(50), unique=True, nullable=False) 
    
    # We store Rupees here. For testing, you'll set these to 1.
    price_rupees = Column(Integer, nullable=False)              
    
    # Limits for locking features
    group_limit = Column(Integer, nullable=False)               
    member_limit = Column(Integer, nullable=False)              
    
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)