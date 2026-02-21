from pydantic import BaseModel
from typing import Optional

class QuickRules(BaseModel):
    # Core Logic
    chit_type: str              # KULUKAL / AUCTION
    monthly_due_type: str       # FIXED / VARIABLE
    installment_amount: int
    
    # Prize Rules
    prize_mode: str             # CURVE / FLAT / AUCTION
    first_prize: int            # Starting value for Curve or Flat value
    last_prize: int             # Ending value for Curve
    
    # Foreman Logic
    foreman_type: str           # FULL_MONTH / PERCENTAGE
    foreman_val: int            # 0 for "Any", 1-50 for "Specific", or % value
    
    # Reserve Settings
    carry_forward: bool
    allow_multiple_auction: bool
    use_for_final_payout: bool
    use_for_last_month_reduce: bool

    # Schedule
    frequency: str              # MONTHLY_DATE / WEEKLY
    schedule_val: int           # Day of month (1-31) or Day of week (1-7)

class QuickChitRequest(BaseModel):
    group_name: str
    chit_amount: int
    total_slots: int
    duration_months: int
    rules: QuickRules