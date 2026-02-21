from typing import List, Dict
from datetime import date, timedelta
import calendar

# =========================================================
# 1. RULE VALIDATION
# =========================================================

def validate_rules(settings: Dict):
    chit_type = settings["chit_type"] # Options: KULUKAL, AUCTION, CUSTOM
    prize_rule = settings["prize_rule"]
    monthly_due = settings["monthly_due"]
    reserve_rule = settings["reserve_rule"]
    dividend = settings["dividend_rule"]

    # ---- 1. Chit Type Specific Validations ----
    if chit_type == "KULUKAL":
        # Rule: Kulukal (Booklet or Simple) must have FIXED monthly due
        if monthly_due["type"] != "FIXED":
            raise ValueError("Kulukal must have FIXED monthly due")

        # Rule: Kulukal must be CURVE (Booklet) or FLAT (Simple)
        if prize_rule["mode"] not in ["CURVE", "FLAT"]:
            raise ValueError("Kulukal must use CURVE or FLAT prize mode")

        # Rule: Kulukal must use PRIZE dividend type with NONE distribution
        if dividend["type"] != "PRIZE":
            raise ValueError("Kulukal must use PRIZE dividend type")
        if dividend["distribution"] != "NONE":
            raise ValueError("Kulukal must have NONE distribution")

    elif chit_type == "AUCTION":
        # Rule: Auction must use AUCTION prize mode
        if prize_rule["mode"] != "AUCTION":
            raise ValueError("Auction chit must use AUCTION prize mode")
        
        if not settings.get("auction_rule"):
            raise ValueError("Auction rules (limits/base type) are required")

    # ---- 2. Reserve vs Due Dependency ----
    # Rule: If Installment is variable, reserve pool is NOT carried forward
    if monthly_due["type"] == "VARIABLE":
        if reserve_rule.get("carry_forward") is True:
            raise ValueError("If monthly due is VARIABLE, reserve pool cannot be carried forward")

    # ---- 3. Foreman Rule Validation ----
    foreman = settings["foreman_rule"]
    if foreman["type"] == "PERCENTAGE" and foreman.get("percentage") is None:
        raise ValueError("Foreman percentage required")
    if foreman["type"] == "FULL_MONTH" and foreman.get("month_no") is None:
        raise ValueError("Foreman full month number required")

    # ---- 4. Schedule Rule Validation ----
    schedule = settings["schedule_rule"]
    if schedule["frequency"] == "MONTHLY_DATE":
        if not schedule.get("day"):
            raise ValueError("Day of month required for schedule")
    elif schedule["frequency"] == "MONTHLY_WEEKDAY":
        if schedule.get("week") is None or schedule.get("weekday") is None:
            raise ValueError("Week and Weekday required for schedule")

    # ---- 5. Dividend Distribution Check ----
    if dividend["type"] == "DIVIDEND" and dividend["distribution"] == "NONE":
        raise ValueError("Dividend distribution cannot be NONE if type is DIVIDEND")

    return True


# =========================================================
# 2. BOOKLET PIECEWISE CURVE (SCALED FOR ANY AMOUNT)
# =========================================================

from typing import List

def generate_booklet_piecewise_curve(
    chit_amount: int,
    months: int,
    foreman_month: int = 1
    ) -> List[int]:
    """
    Generates exact Kulukal curve based on booklet.
    Scales for any chit amount.
    Foreman month can be any month.
    """

    scale = chit_amount / 100000

    base_first_prize = int(90000 * scale)

    increments = (
        [1000] +               # Month 3
        [500] * 8 +            # Month 4–11
        [1000] * 3 +           # Month 12–14
        [2500, 3000, 3500] +   # 15,16,17
        [4000, 4000] +         # 18,19
        [5000, 5000]           # 20,21
    )

    # Build prize ladder (without foreman month)
    prize_values = [base_first_prize]
    current = base_first_prize

    for inc in increments:
        current += int(inc * scale)
        prize_values.append(current)

    while len(prize_values) < months:
        current += int(5000 * scale)
        prize_values.append(current)

    # Final month-wise curve
    curve = []
    prize_idx = 0

    for m in range(1, months + 1):
        if m == foreman_month:
            curve.append(chit_amount)   # Foreman takes chit amount
        else:
            curve.append(prize_values[prize_idx])
            prize_idx += 1

    return curve




# =========================================================
# 3. PREVIEW GENERATOR
# =========================================================

def build_preview(settings: Dict, chit_amount: int, months: int):
    """
    Generates a month-by-month projection of the chit group.
    - Handles KULUKAL (Curve vs Flat)
    - Handles AUCTION (Bid-based placeholders)
    - Handles Foreman month exclusions
    """
    chit_type = settings["chit_type"]
    prize_rule = settings["prize_rule"]
    foreman_rule = settings["foreman_rule"]
    
    # Safely get foreman month (default to month 1 if not specified)
    foreman_month = foreman_rule.get("month_no", 1)
    
    # 1. Initialize the skeleton for all months
    preview = []
    for m in range(1, months + 1):
        preview.append({
            "month": m,
            "type": "COLLECTION", # Default state
            "payout": None
        })

    # 2. Assign Foreman Slot
    # If FULL_MONTH type, the foreman takes the entire chit_amount as payout
    if foreman_rule["type"] == "FULL_MONTH":
        # Adjust for 0-based index
        idx = foreman_month - 1
        if 0 <= idx < months:
            preview[idx]["type"] = "FOREMAN"
            preview[idx]["payout"] = chit_amount

    # 3. Apply Chit Type Logic
    if chit_type == "KULUKAL":
        # Mode: FLAT (This replaces the old SIMPLE_KULUKAL type)
        if prize_rule["mode"] == "FLAT":
            payout_val = prize_rule.get("first_prize")
            for i in range(months):
                if preview[i]["type"] != "FOREMAN":
                    preview[i]["type"] = "PRIZE"
                    preview[i]["payout"] = payout_val
        
        # Mode: CURVE (The piecewise booklet logic)
        elif prize_rule["mode"] == "CURVE":
            curve = generate_booklet_piecewise_curve(
                chit_amount=chit_amount,
                months=months,
                foreman_month=foreman_month
            )
            # Match curve values to the preview months
            for i in range(months):
                if preview[i]["type"] != "FOREMAN":
                    preview[i]["type"] = "PRIZE"
                    preview[i]["payout"] = curve[i]

    elif chit_type == "AUCTION":
        # Auctions don't have pre-determined prizes, so we set placeholders
        for i in range(months):
            if preview[i]["type"] != "FOREMAN":
                preview[i]["type"] = "AUCTION"
                preview[i]["payout"] = "BID_BASED"

    # 4. Attach to settings and return
    settings["preview"] = preview
    return settings




# =========================================================
# 4. PRIZE CALCULATION (RUNTIME ENGINE)
# =========================================================

def calculate_prize(settings, month_no, total_collection, winning_bid_amount=None):
    chit_type = settings["chit_type"]

    if chit_type in ["KULUKAL", "SIMPLE_KULUKAL"]:
        return settings["preview"][month_no - 1]["payout"]

    if chit_type == "AUCTION":
        return total_collection - (winning_bid_amount or 0)

    # Custom fallback
    payout_model = settings.get("payout_model")

    if payout_model == "FIXED":
        return settings["fixed_prize_amount"]

    if payout_model == "PROGRESSIVE":
        return total_collection - (month_no * settings["installment_amount"])

    if payout_model == "AUCTION":
        return total_collection - (winning_bid_amount or 0)

    raise ValueError("Unknown payout model")


# =========================================================
# 5. DIVIDEND CALCULATION
# =========================================================

#def calculate_dividend(settings, total_collection, foreman_commission, prize_amount, total_members):
#    dividend_rule = settings["dividend_rule"]
#    surplus = total_collection - foreman_commission - prize_amount
#
#    if dividend_rule["distribution"] == "NONE":
#        return 0, surplus
#
#    if dividend_rule["distribution"] == "FIXED":
#        return dividend_rule["fixed_amount"], surplus
#
#    if dividend_rule["distribution"] == "VARIABLE":
#        return int(surplus / total_members), surplus
#
#    return 0, surplus

def calculate_dividend(
    settings,
    total_collection,
    foreman_commission,
    prize_amount,
    total_members
):
    dividend_rule = settings["dividend_rule"]

    # Pool available for dividend + surplus
    available = total_collection - foreman_commission - prize_amount

    if available <= 0 or total_members <= 0:
        return 0, 0

    distribution = dividend_rule["distribution"]

    # 1️⃣ No dividend → everything goes to surplus
    if distribution == "NONE":
        return 0, available

    # 2️⃣ Fixed dividend per member
    if distribution == "FIXED":
        fixed = int(dividend_rule.get("fixed_amount", 0))
        total_dividend = fixed * total_members

        if total_dividend >= available:
            # Cap dividend to avoid negative surplus
            per_member = int(available / total_members)
            surplus = available - (per_member * total_members)
            return per_member, surplus

        surplus = available - total_dividend
        return fixed, surplus

    # 3️⃣ Variable dividend (equal distribution)
    if distribution == "VARIABLE":
        per_member = int(available / total_members)
        surplus = available - (per_member * total_members)
        return per_member, surplus

    # Fallback safety
    return 0, available



# =========================================================
# 6. SCHEDULE NEXT RUN DATE (BASIC)
# =========================================================

def calculate_next_run_date(start_date: date, rule: dict) -> date:
    freq = rule.get("frequency")

    if freq == "MONTHLY_DATE":
        day = rule.get("day", 1)  # default safe

        year = start_date.year
        month = start_date.month + 1
        if month > 12:
            month = 1
            year += 1

        last_day = calendar.monthrange(year, month)[1]
        return date(year, month, min(day, last_day))

    if freq == "MONTHLY_WEEKDAY":
        # Example: 1st Friday, 3rd Monday
        week = rule.get("week", 1)          # 1..5
        weekday = rule.get("weekday", 0)    # 0=Mon .. 6=Sun

        year = start_date.year
        month = start_date.month + 1
        if month > 12:
            month = 1
            year += 1

        first_day = date(year, month, 1)
        first_weekday = first_day.weekday()
        delta = (weekday - first_weekday + 7) % 7

        target = first_day + timedelta(days=delta + (week - 1) * 7)

        # 🔥 SAFETY: If 5th weekday doesn't exist, fall back to last such weekday
        if target.month != month:
            last_day = calendar.monthrange(year, month)[1]
            last_date = date(year, month, last_day)
            last_weekday = last_date.weekday()
            back_delta = (last_weekday - weekday + 7) % 7
            target = last_date - timedelta(days=back_delta)

        print("🔥 calendar module =", calendar)
        return target

    raise ValueError("Invalid schedule rule")


# =========================================================
# 7. CONFIGURE PIPELINE HOOK
# =========================================================

def enrich_and_validate(
    settings: Dict,
    chit_amount: int,
    duration_months: int,
    total_slots: int
    ):
    # 1. Business rule validation
    validate_rules(settings)

    # 2. Generate preview (foreman, kulukal curve, auction placeholders)
    settings = build_preview(
        settings=settings,
        chit_amount=chit_amount,
        months=duration_months
    )

    return settings
