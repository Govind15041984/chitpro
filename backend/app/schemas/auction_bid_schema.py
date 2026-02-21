from pydantic import BaseModel
from typing import List
from uuid import UUID
from datetime import datetime


class AuctionBidCreateRequest(BaseModel):
    member_id: UUID
    bid_amount: int


class AuctionBidResponse(BaseModel):
    id: UUID
    member_id: UUID
    bid_amount: int
    created_at: datetime


class AuctionBidListResponse(BaseModel):
    bids: List[AuctionBidResponse]
