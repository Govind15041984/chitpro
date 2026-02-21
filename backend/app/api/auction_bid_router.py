from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.database import SessionLocal
from app.schemas.auction_bid_schema import (
    AuctionBidCreateRequest,
    AuctionBidListResponse,
    AuctionBidResponse
)
from app.services.auction_bid_service import place_bid, list_bids

router = APIRouter(tags=["Auction Bids"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/{auction_round_id}", response_model=AuctionBidResponse)
def create_bid(auction_round_id: UUID, data: AuctionBidCreateRequest, db: Session = Depends(get_db)):
    bid = place_bid(db, auction_round_id, data.member_id, data.bid_amount)
    return bid


@router.get("/{auction_round_id}", response_model=AuctionBidListResponse)
def get_bids(auction_round_id: UUID, db: Session = Depends(get_db)):
    bids = list_bids(db, auction_round_id)
    return {"bids": bids}
