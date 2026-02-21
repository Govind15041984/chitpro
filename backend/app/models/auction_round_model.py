import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer, Boolean
from sqlalchemy.dialects.postgresql import UUID, JSONB

from app.core.database import Base


class AuctionRound(Base):
    __tablename__ = "auction_rounds"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chit_group_id = Column(UUID(as_uuid=True), ForeignKey("chit_groups.id"), nullable=False)

    month_no = Column(Integer, nullable=False)
    round_no = Column(Integer, nullable=False)

    total_collection = Column(Integer, nullable=False)
    winning_member_id = Column(UUID(as_uuid=True), ForeignKey("chit_members.id"), nullable=True)
    winning_bid_amount = Column(Integer, nullable=True)

    foreman_commission = Column(Integer, nullable=False)
    dividend_per_member = Column(Integer, nullable=False)
    reserve_amount = Column(Integer, nullable=False)
    payout_amount = Column(Integer, nullable=False)

    calculation_snapshot = Column(JSONB, nullable=False)

    status = Column(String(20), default="OPEN")  # OPEN, CLOSED

    is_auto = Column(Boolean, default=False)
    auto_reason = Column(String(50), nullable=True)  # FOREMAN_COMMISSION

    created_at = Column(DateTime, default=datetime.utcnow)
