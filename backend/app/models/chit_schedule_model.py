# app/models/chit_schedule_model.py
import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID, JSONB
from app.core.database import Base

class ChitSchedule(Base):
    __tablename__ = "chit_schedules"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chit_group_id = Column(UUID(as_uuid=True), ForeignKey("chit_groups.id"), nullable=False)

    schedule_type = Column(String(20), nullable=False)
    # FIXED_DATE, NTH_WEEKDAY, INTERVAL, CUSTOM

    rule = Column(JSONB, nullable=False)
    # {
    #   "day": 15
    # } OR
    # {
    #   "week": 1, "weekday": "MONDAY"
    # } OR
    # {
    #   "interval_days": 30
    # }

    start_date = Column(DateTime, nullable=False)
    next_run = Column(DateTime, nullable=False)

    status = Column(String(20), default="ACTIVE")  # ACTIVE, PAUSED, COMPLETED
    created_at = Column(DateTime, default=datetime.utcnow)
    