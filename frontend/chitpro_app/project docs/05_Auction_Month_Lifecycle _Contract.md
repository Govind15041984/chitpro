    1️⃣ Chit Lifecycle (High-Level)
    
    States:
    
    DRAFT → CONFIGURED → ACTIVE → RUNNING → CLOSED
    
    
    ACTIVE → Chit is ready, members added
    
    RUNNING → Monthly operations (auction + collection) can happen
    
    CLOSED → Chit completed
    
    2️⃣ Month Lifecycle (Inside RUNNING)
    
    Each month is an operational unit controlled by the foreman.
    
    🔹 Month Start
    
    Triggered when:
    
    Foreman clicks Start Month – N
    
    OR implicitly when first auction is opened
    
    Rules:
    
    current_month_no remains unchanged until month is closed
    
    A month is considered active once an auction round for that month is opened
    
    3️⃣ Auction Round (Month Session Record)
    
    An AuctionRound represents one month’s session.
    
    🔸 On Open (Run Auction / Start Month)
    
    Create AuctionRound with:
    
    month_no = next month (current_month_no + 1)
    status = OPEN
    total_collection = 0
    foreman_commission = 0
    dividend_per_member = 0
    reserve_amount = 0
    payout_amount = 0
    calculation_snapshot = {}
    
    4️⃣ Foreman Month Behavior (FULL_MONTH Rule)
    
    If:
    
    foreman_rule.type = FULL_MONTH
    foreman_rule.month_no = current month
    
    
    Then:
    
    No auction UI is shown
    
    System shows popup:
    
    “Foreman month – No auction. Winner: Company”
    
    AuctionRound:
    
    is_auto = true
    auto_reason = FOREMAN_MONTH
    status = OPEN
    winner = Company (implicit)
    payout_amount = chit_amount (finalized on month close)
    
    
    💡 Important:
    Foreman month still has collections. Members must pay monthly dues.
    
    5️⃣ Auction Month Behavior (Normal Month)
    
    Auction screen opens
    
    Foreman selects winner (spin/manual)
    
    AuctionRound remains OPEN
    
    Winner is stored
    
    6️⃣ Member Ledger Creation
    
    Ledger entries are created when the month starts (not at close):
    
    For each active member:
    
    MemberLedger:
      chit_group_id
      member_id
      month_no
      installment_amount
      dividend_amount (initially 0)
      net_payable
      payment_status = PENDING
    
    
    This enables:
    
    Collection UI to appear immediately
    
    Foreman to start collecting dues
    
    7️⃣ Collections (Live During Month)
    
    As foreman marks payments:
    
    MemberLedger.payment_status = PAID
    
    auction_round.total_collection += ledger.net_payable
    
    UI shows:
    
    Total Expected: members × monthly_due
    Collected So Far: auction.total_collection
    Surplus: computed (if applicable)
    
    8️⃣ Month Close (Explicit Action by Foreman)
    
    Triggered only when foreman clicks Close Month.
    
    Backend validations:
    
    All MemberLedger entries for that month are PAID
    
    No OPEN auctions left
    
    On close:
    
    auction_round.status = CLOSED
    auction_round.payout_amount = chit_amount (foreman month) OR auction prize
    auction_round.reserve_amount = final reserve
    auction_round.dividend_per_member = final dividend
    auction_round.calculation_snapshot = frozen snapshot
    chit_group.current_month_no += 1
    
    
    Month is now finalized and immutable.
    
    9️⃣ UI Rendering Rules
    Current Month Card
    
    If no auction yet:
    
    Status: Month Started – No Auction Yet
    
    
    Foreman month:
    
    Status: Foreman Month – Collect Payments
    Winner: Company
    Prize: Chit Amount
    
    
    Auction month:
    
    Status: Winner Decided / Collections Pending
    Winner: Member X
    
    Payments Section
    
    Visible when:
    
    AuctionRound exists for current month
    
    Status = OPEN
    
    Not tied to current_month_no, tied to auction_round.month_no
    
    🔒 Invariants (Must Always Hold)
    
    current_month_no increments only on Close Month
    
    Foreman month:
    
    No auction
    
    But collections still happen
    
    auction.total_collection is a running total
    
    Final accounting is frozen on month close
    
    🧠 Why This Design
    
    Matches real-world chit process
    
    Supports:
    
    Multiple auctions per month (future)
    
    Partial collections
    
    Transparent progress tracking
    
    Clean separation:
    
    AuctionRound = month session + summary
    
    MemberLedger = per-member truth