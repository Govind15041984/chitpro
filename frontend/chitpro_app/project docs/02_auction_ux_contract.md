# ChitPro – Auction & Month Lifecycle UX Contract (v1)

## 1. Chit Status
- Chit remains in RUNNING state for the entire duration (e.g., 21 months).
- Month lifecycle is separate from chit lifecycle.

## 2. Month Lifecycle
Each month has its own state:
- NOT_STARTED → OPEN → CLOSED

### Start Month
- Foreman must explicitly start each month.
- UI action: "Start Month – N"
- Before starting month:
    - Auction and collections are disabled.

### Open Month
- Foreman can:
    - Run auction (multiple times if reserve allows)
    - Collect payments
- Auction is rule-aware and only decides winner.
- Winner change allowed until collections begin.

### Close Month
- Enabled only when:
    - All auctions for the month are completed
    - All dues for the month are fully collected
- Closing month:
    - Locks history for that month
    - Increments current month

## 3. Auction UX
- Auction screen responsibility:
    - Decide winner only
    - No collections
    - No surplus handling
- Winner selection:
    - Spin mode or Manual mode
- Rule-aware:
    - Auction must respect full rule engine from DB
- Winner change:
    - Allowed before collections begin
    - After collections → warn / restrict
    - After month close → not allowed

## 4. Auction History
- Closed months are read-only
- History shows:
    - Month number
    - All auctions in that month
    - Winner & payout
