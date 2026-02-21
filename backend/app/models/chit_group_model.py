import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID, JSONB

from app.core.database import Base

class ChitGroup(Base):
    __tablename__ = "chit_groups"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    admin_id = Column(UUID(as_uuid=True), ForeignKey("admins.id"), nullable=False)

    group_name = Column(String(100), nullable=False)
    chit_amount = Column(Integer, nullable=False)
    total_slots = Column(Integer, nullable=False)
    duration_months = Column(Integer, nullable=False)
    current_month_no = Column(Integer, nullable=False, default=0)

    # Rule Engine
    settings = Column(JSONB, nullable=True)  # nullable until CONFIGURED

    # Lifecycle
    lifecycle_status = Column(String(20), default="DRAFT")
    # DRAFT, CONFIGURED, ACTIVE, RUNNING, CLOSED

    # Scheduling
    start_date = Column(DateTime, nullable=True)

    schedule_type = Column(String(20), nullable=True)
    # MONTHLY_DATE, MONTHLY_WEEKDAY

    schedule_day = Column(Integer, nullable=True)        # 1..31
    schedule_week = Column(Integer, nullable=True)       # 1,2,3,4,-1
    schedule_weekday = Column(String(10), nullable=True) # MON,TUE...

    next_run_date = Column(DateTime, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)


