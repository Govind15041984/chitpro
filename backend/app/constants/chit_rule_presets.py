KULUKAL_PRESET = {
    "chit_type": "KULUKAL",
    "monthly_due": {"type": "FIXED", "amount": 10000},
    "prize_rule": {"mode": "CURVE", "first_prize": 180000, "last_prize": 250000},
    "dividend_rule": {"type": "PRIZE", "distribution": "NONE"},
    "reserve_rule": {"carry_forward": True, "allow_multiple_auction": True},
    "foreman_rule": {"type": "FULL_MONTH", "percentage": None},
    "auction_rule": None,
    "schedule_rule": {"frequency": "MONTHLY_DATE", "day": 15}
}

SIMPLE_KULUKAL_PRESET = {
    "chit_type": "SIMPLE_KULUKAL",
    "monthly_due": {"type": "FIXED", "amount": 10000},
    "prize_rule": {"mode": "FLAT", "first_prize": 200000, "last_prize": 200000},
    "dividend_rule": {"type": "PRIZE", "distribution": "NONE"},
    "reserve_rule": {"carry_forward": True, "allow_multiple_auction": False},
    "foreman_rule": {"type": "FULL_MONTH", "percentage": None},
    "auction_rule": None,
    "schedule_rule": {"frequency": "MONTHLY_DATE", "day": 15}
}

AUCTION_PRESET = {
    "chit_type": "AUCTION",
    "monthly_due": {"type": "VARIABLE", "amount": None},
    "prize_rule": {"mode": "AUCTION"},
    "dividend_rule": {"type": "DIVIDEND", "distribution": "VARIABLE"},
    "reserve_rule": {"carry_forward": True, "allow_multiple_auction": True},
    "foreman_rule": {"type": "PERCENTAGE", "percentage": 5},
    "auction_rule": {"base_type": "AUTO_REDUCED", "auto_reduce_pct": 5},
    "schedule_rule": {"frequency": "MONTHLY_DATE", "day": 15}
}
