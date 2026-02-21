from pydantic import BaseModel, model_validator
from typing import Optional, List


class MonthlyDueRule(BaseModel):
    type: str  # FIXED / VARIABLE
    amount: Optional[int] = None


class PrizeRule(BaseModel):
    mode: str  # CURVE / FLAT / AUCTION
    first_prize: Optional[int] = None
    last_prize: Optional[int] = None
    curve_model: Optional[str] = "BOOKLET_PIECEWISE"


class DividendRule(BaseModel):
    type: str  # PRIZE / DIVIDEND
    distribution: str  # NONE / FIXED / VARIABLE
    fixed_amount: Optional[int] = None


class ReserveRule(BaseModel):
    carry_forward: bool
    allow_multiple_auction: bool
    use_for_last_month_reduce: bool = False
    use_for_final_payout: bool = False


class ForemanRule(BaseModel):
    type: str  # FULL_MONTH / PERCENTAGE
    percentage: Optional[int] = None
    month_no: Optional[int] = None


class AuctionRule(BaseModel):
    base_type: str  # MANUAL / AUTO_REDUCED
    auto_reduce_pct: Optional[int] = None
    min_bid_pct: Optional[int] = None
    max_bid_pct: Optional[int] = None


class ScheduleRule(BaseModel):
    frequency: str  # MONTHLY_DATE / MONTHLY_WEEKDAY
    day: Optional[int] = None
    week: Optional[int] = None
    weekday: Optional[int] = None


class ChitPreview(BaseModel):
    month_wise_prize: List[int]
    month_wise_due: List[int]
    month_wise_reserve: List[int]


class ChitRuleSettingsV2(BaseModel):
    chit_type: str  # KULUKAL / SIMPLE_KULUKAL / AUCTION / CUSTOM

    monthly_due: MonthlyDueRule
    prize_rule: PrizeRule
    dividend_rule: DividendRule
    reserve_rule: ReserveRule
    foreman_rule: ForemanRule
    auction_rule: Optional[AuctionRule] = None
    schedule_rule: ScheduleRule

    preview: Optional[ChitPreview] = None

    @model_validator(mode="after")
    def validate_rules(self):
        chit_type = self.chit_type

        if chit_type in ["KULUKAL", "SIMPLE_KULUKAL"]:
            if self.prize_rule.mode not in ["CURVE", "FLAT"]:
                raise ValueError("Kulukal must use CURVE or FLAT prize mode")

        if chit_type == "AUCTION":
            if self.prize_rule.mode != "AUCTION":
                raise ValueError("Auction chit must use AUCTION prize mode")

        if not self.reserve_rule.carry_forward and self.monthly_due.type != "VARIABLE":
            raise ValueError("For this chit type, reserve must be carried forward. Please enable carry-forward in Reserve settings.")

        if self.foreman_rule.type == "PERCENTAGE" and self.foreman_rule.percentage is None:
            raise ValueError("Foreman percentage required")

        if self.foreman_rule.type == "FULL_MONTH" and self.foreman_rule.month_no is None:
            raise ValueError("Foreman full month number required")

        # ---- Dividend Rules ----
        if self.dividend_rule.type == "DIVIDEND" and self.dividend_rule.distribution == "NONE":
            raise ValueError("DIVIDEND type cannot have NONE distribution")

        if chit_type in ["KULUKAL", "SIMPLE_KULUKAL"]:
            if self.dividend_rule.type != "PRIZE":
                raise ValueError("Kulukal must be PRIZE type")
            if self.dividend_rule.distribution != "NONE":
                raise ValueError("Kulukal must have NONE distribution")

        return self
