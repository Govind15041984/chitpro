from sqlalchemy.orm import Session
from app.models.auction_bid_model import AuctionBid
from app.models.auction_round_model import AuctionRound


def place_bid(db: Session, auction_round_id, member_id, bid_amount: int):
    bid = AuctionBid(
        auction_round_id=auction_round_id,
        member_id=member_id,
        bid_amount=bid_amount
    )
    db.add(bid)
    db.commit()
    db.refresh(bid)
    return bid


def list_bids(db: Session, auction_round_id):
    return db.query(AuctionBid).filter(
        AuctionBid.auction_round_id == auction_round_id
    ).order_by(AuctionBid.bid_amount.asc()).all()


def get_lowest_bid(db: Session, auction_round_id):
    return db.query(AuctionBid).filter(
        AuctionBid.auction_round_id == auction_round_id
    ).order_by(AuctionBid.bid_amount.asc()).first()
