1️⃣ Slot Add (Increase Slots for a Member)
✅ Allowed When:

Chit status is ACTIVE or RUNNING

Current month has NOT started

📌 Behaviour:

New slot is treated as a late-joiner slot

Member must pay catch-up amount for all past months

member_ledger must:

Create entries from joining_month → current_month

Slot record must store:

joined_month

Slot ownership (member reference)

🚫 Not Allowed When:

Current month has started
→ Slot structure is frozen for the month

2️⃣ Slot Delete (Reducing Slots)

Slot deletion is highly restricted to preserve accounting correctness.

✅ Allowed Only When:

Slot has never participated in any month

No member_ledger entries exist for that slot

Slot has not been part of any auction

joined_month > current_month

👉 This is typically a mistake correction scenario.

🚫 Not Allowed When:

Slot has any ledger history

Slot has participated in any auction

Slot has ever won a prize

In such cases, slot deletion is forbidden.

3️⃣ Slot Transfer (Replace Member on a Slot)

This supports real-world cases like:

“Member wants to leave, another person will take over the slot.”

✅ Allowed When:

Slot has not been prized

Current month has not started

📌 Behaviour:

Slot remains the same (slot ID / member_no)

Ownership of slot changes to a new member

Historical ledger remains untouched

New member continues from current month onwards

🚫 Not Allowed When:

Slot is already prized

Current month has started

4️⃣ Prized Slot Lock

Once a slot has won a prize:

🔒 Permanently Locked:

❌ Cannot delete

❌ Cannot transfer

❌ Cannot rename ownership

❌ Cannot reduce slot count

This is to ensure:

Financial correctness

Legal defensibility

Audit trail integrity

5️⃣ Month Lock Rule (Global Slot Freeze)

Once a month is started:

🔒 Slot Structure Frozen:

❌ No slot add

❌ No slot delete

❌ No slot transfer

All slot changes must happen before starting a month.

6️⃣ Member Profile Edit vs Slot Ownership

These two are different:

Action	Allowed?	Affects Ledger?
Rename member display name	✅ Yes	❌ No
Correct mobile number	✅ Yes	❌ No
Change slot ownership	⚠️ Only via Slot Transfer	❌ No
7️⃣ Design Principles (Why These Rules Exist)

These rules ensure:

✅ MemberLedger always reflects financial truth

✅ Auctions remain fair and traceable

✅ Reserve calculations stay correct

✅ Temple / chit audit remains legally defensible

✅ Foreman operations remain simple & predictable

8️⃣ Developer Notes (For Backend & UI)

Backend must enforce:

Slot state checks (prized / joined_month / ledger existence)

Month started guard

Frontend must:

Disable Add / Delete / Transfer actions once month starts

Show clear error messages for forbidden operations

Guide user to slot transfer instead of delete