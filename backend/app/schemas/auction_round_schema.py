from pydantic import BaseModel
from typing import Optional, Dict, Any
from uuid import UUID
from datetime import datetime


# ===============================
# REQUESTS
# ===============================

class AuctionRoundOpenRequest(BaseModel):
    pass


class AuctionRoundCloseRequest(BaseModel):
    winning_member_id: UUID
    winning_bid_amount: Optional[int] = None


# ===============================
# RESPONSES
# ===============================

class LiveAuctionRoundResponse(BaseModel):
    id: UUID
    chit_group_id: UUID
    month_no: int
    status: str

    winning_member_id: Optional[UUID] = None
    winning_bid_amount: Optional[int] = None

    is_auto: bool = False
    auto_reason: Optional[str] = None

    class Config:
        from_attributes = True



class AuctionRoundResultResponse(BaseModel):
    auction_round_id: UUID
    month_no: int

    winning_member_id: UUID
    winning_bid_amount: Optional[int]

    total_collection: int
    foreman_commission: int
    dividend_per_member: int
    reserve_amount: int
    payout_amount: int

    calculation_snapshot: Dict[str, Any]
    status: str

    class Config:
        from_attributes = True
