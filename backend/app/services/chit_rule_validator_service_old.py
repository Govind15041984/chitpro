def validate_rules(settings: ChitRuleSettingsV2):
    if settings.chit_type in ["KULUKAL", "SIMPLE_KULUKAL"]:
        if settings.monthly_due_type != "FIXED":
            raise ValueError("Kulukal must have fixed monthly due")

        if settings.foreman_rule.mode == "FULL_MONTH":
            settings.foreman_rule.month_no = 1  # locked

        if settings.dividend_mode != "PRIZE":
            raise ValueError("Kulukal must be Prize mode")

    if settings.chit_type == "AUCTION":
        if not settings.auction_rule:
            raise ValueError("Auction rules required")

    if settings.chit_type == "CUSTOM":
        pass  # full freedom
