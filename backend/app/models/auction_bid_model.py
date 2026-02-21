import uuid
from datetime import datetime
from sqlalchemy import Column, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base


class AuctionBid(Base):
    __tablename__ = "auction_bids"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    auction_round_id = Column(UUID(as_uuid=True), ForeignKey("auction_rounds.id"), nullable=False)
    member_id = Column(UUID(as_uuid=True), ForeignKey("chit_members.id"), nullable=False)

    bid_amount = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
