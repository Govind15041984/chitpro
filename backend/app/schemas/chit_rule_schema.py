from pydantic import BaseModel
from typing import Optional, Dict


class ChitRuleSettings(BaseModel):
    # Core amounts
    installment_amount: int

    # Payout behaviour
    payout_model: str  # PROGRESSIVE, FIXED, AUCTION
    fixed_prize_amount: Optional[int] = None  # used if FIXED

    # Dividend behaviour
    dividend_model: str  # FIXED, VARIABLE, BID_BASED
    fixed_dividend_amount: Optional[int] = None  # if FIXED

    # Surplus handling
    surplus_handling: str  # CARRY_FORWARD, EXTRA_SLOT, LAST_MONTH_REDUCE
    allow_double_auction: bool = False

    # Foreman
    foreman_commission_pct: int

    # Auction rules (if AUCTION or BID_BASED)
    min_bid_pct: Optional[int] = None
    max_bid_pct: Optional[int] = None

    # Last month special rules
    last_month_reduce_installment: bool = False
    use_reserve_pool_for_last_month: bool = False

    # Custom village / temple rules
    custom_rules: Optional[Dict] = None
