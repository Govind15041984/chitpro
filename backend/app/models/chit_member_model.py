import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base


class ChitMember(Base):
    __tablename__ = "chit_members"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chit_group_id = Column(UUID(as_uuid=True), ForeignKey("chit_groups.id"), nullable=False)

    name = Column(String(100), nullable=False)
    mobile_number = Column(String(15), nullable=True)
    member_no = Column(Integer, nullable=False)  # slot number

    joined_month = Column(Integer, nullable=False)  # 🔥 NEW
    joined_at = Column(DateTime, default=datetime.utcnow)

    status = Column(String(20), default="ACTIVE")  # ACTIVE, PRIZED, CLOSED
