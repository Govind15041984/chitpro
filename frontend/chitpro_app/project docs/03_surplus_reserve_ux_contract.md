# ChitPro – Surplus / Reserve Pool UX Contract (v1)

## 1. Definitions
- Month Collection: Money collected in current month (resets monthly)
- Reserve Pool: Persistent balance across months

## 2. Display Rules
- Reserve Pool balance must always be visible on Chit Detail screen
- Show:
    - Opening balance
    - Additions in current month
    - Current balance

## 3. After Each Auction
- Show breakdown:
    - Collected from members
    - Paid to winner
    - Added to reserve
    - Updated reserve pool balance

## 4. Extra Auction Trigger
- When reserve >= rule-defined threshold (e.g., chit amount):
    - UI shows suggestion: "Run Extra Auction"
- System must not auto-trigger auctions
- Foreman decides when to run extra auction

## 5. End of Month
- Before closing month:
    - Show reserve pool movement summary
- Reserve pool carries forward to next month

## 6. Final Month Behaviour
- If reserve pool covers part of chit amount:
    - Member dues are reduced
- UI must show reduced due and reason

## 7. History & Audit
- Reserve pool history visible:
    - Month-wise changes
    - Additions and usages
- Closed months are immutable
