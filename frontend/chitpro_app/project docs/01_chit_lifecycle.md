# ChitPro – Chit Lifecycle & Month Lifecycle Contract (v1)

This document defines the **official lifecycle of a chit group** in ChitPro and the **monthly operational lifecycle** inside a running chit.  
This is the product contract and must be followed by UI, backend APIs, and state engine.

---

## 1. Chit Group Lifecycle (High-Level)

Chit Group lifecycle states:

DRAFT → CONFIGURED → ACTIVE → RUNNING → CLOSED

Each state has a clear meaning and strict rules on when transitions happen.

---

## 2. Chit Group States – Meaning & Transitions

### 2.1 DRAFT
**Meaning:**
- Chit group basic info is being created.
- Example:
    - Group name
    - Chit amount
    - Duration months
    - Base installment

**Allowed Actions:**
- Edit basic chit info
- Delete chit group

**When status updates to CONFIGURED:**
- All rule blocks are configured:
    - Prize Rule
    - Installment Rule
    - Foreman Commission Rule
    - Dividend Rule
    - Reserve Pool Rule

---

### 2.2 CONFIGURED
**Meaning:**
- Chit rules are fully defined.
- No members yet, or members not finalized.

**Allowed Actions:**
- View / update rule settings
- Review chit configuration

**When status updates to ACTIVE:**
- Minimum required setup is complete
- Foreman explicitly activates the chit
- Members can now be added

---

### 2.3 ACTIVE
**Meaning:**
- Chit is open for member onboarding.
- No monthly operations yet.

**Allowed Actions:**
- Add members / slots
- Late joiners allowed
- Review rules

**Restrictions:**
- No auctions
- No collections

**When status updates to RUNNING:**
- Foreman starts the chit (Start Chit)
- This marks the beginning of Month 1

---

### 2.4 RUNNING
**Meaning:**
- Chit is operational.
- Monthly lifecycle applies (see Section 3).

**Allowed Actions:**
- Start month
- Run auctions
- Collect payments
- Close month
- View history
- Add late joiners (as per rules)

**Status update behaviour:**
- Chit remains in RUNNING for the entire duration (e.g., 21 months).
- Chit status does NOT change every month.
- Month lifecycle is handled separately.

---

### 2.5 CLOSED
**Meaning:**
- Chit has completed all months.
- Financially and operationally complete.

**When status updates to CLOSED:**
- Last month is closed successfully
- All auctions completed
- All dues settled
- No pending balances

**Restrictions:**
- Entire chit becomes read-only
- History only (no edits)

---

## 3. Month Lifecycle (Inside RUNNING Chit)

Each month has its own lifecycle independent of chit status.

Month states:

NOT_STARTED → OPEN → CLOSED

---

### 3.1 NOT_STARTED (Month N)
**Meaning:**
- Month exists conceptually but not yet opened by foreman.
- No auction or collection allowed.

**UI Behaviour:**
- Show:  
  Current Month: N  
  Action: "Start Month – N"

**When month updates to OPEN:**
- Foreman explicitly clicks "Start Month – N"

System actions on Start Month:
- Initialize monthly ledger
- Generate monthly dues for members
- Open month for auction & collection

---

### 3.2 OPEN (Month N)
**Meaning:**
- Month is active and operational.

**Allowed Actions:**
- Run auction (one or more times based on reserve rules)
- Collect member payments
- View reserve pool changes

**Important Rules:**
- Auction can be run multiple times in same month if reserve pool allows extra slots.
- Winner change is allowed until collections begin.
- Payments can be partial or full (as per ledger rules).

---

### 3.3 CLOSED (Month N)
**Meaning:**
- Month operations are complete.
- Financials are locked.

**When month updates to CLOSED:**
- All auctions for the month are completed
- All member dues for the month are fully collected (as per rule engine)
- Foreman clicks "Close Month – N"

System actions on Close Month:
- Lock month ledger
- Lock auction history for the month
- Increment current month (N → N+1)
- Prepare next month in NOT_STARTED state

**Restrictions After Close:**
- No edits to:
    - Winners
    - Payments
    - Reserve pool movements
- Month becomes read-only history

---

## 4. End of Chit (Final Month Handling)

- When the final month is CLOSED:
    - System validates:
        - No pending dues
        - No pending payouts
        - Reserve pool handled as per rules
    - Chit lifecycle moves from RUNNING → CLOSED

---

## 5. Invariants (Must Always Hold True)

- Chit lifecycle and Month lifecycle are independent.
- Chit status remains RUNNING across all months.
- Months must be closed sequentially.
- Closed months are immutable.
- All financial movements must be traceable via history.

---

## 6. Product Principles

- Explicit actions over automatic transitions (Start Month, Close Month)
- Rule engine is the single source of truth
- Auditability and transparency are first-class citizens
- UI must reflect lifecycle state clearly to avoid foreman mistakes
