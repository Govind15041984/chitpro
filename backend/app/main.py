import os
from dotenv import load_dotenv
# 1. LOAD THE ENVIRONMENT FIRST
load_dotenv() 

# 2. DEBUG PRINT (To confirm it works)
print(f"--- STARTUP: RAZORPAY_ID is {os.getenv('RAZORPAY_KEY_ID')} ---")

from fastapi import FastAPI
from app.api.admin_router import router as admin_router
from app.api.subscription_router import router as subscription_router
from app.api.invoice_router import router as invoice_router
from app.api.payment_order_router import router as payment_order_router
from app.api.chit_group_router import router as chit_group_router
from app.api.chit_member_router import router as chit_member_router
from app.api.auction_round_router import router as auction_round_router
from app.api.auction_bid_router import router as auction_bid_router
from app.api.member_ledger_router import router as member_ledger_router
from app.api.dashboard_router import router as dashboard_router
from app.api.grouplink_router import router as grouplink_router
from app.api.quick_create_router import router as qucikcreate_router

app = FastAPI(title="ChitPro API", version="1.0")

app.include_router(admin_router, prefix="/admin")
app.include_router(subscription_router, prefix="/subscription")
app.include_router(invoice_router, prefix="/invoices")
app.include_router(payment_order_router, prefix="/payments")
app.include_router(chit_group_router, prefix="/chit-groups")
app.include_router(chit_member_router, prefix="/chit-members")
app.include_router(auction_round_router, prefix="/auction-rounds")
app.include_router(auction_bid_router, prefix="/auction-bids")
app.include_router(member_ledger_router, prefix="/member-ledger")
app.include_router(dashboard_router, prefix="/dashboard")
app.include_router(grouplink_router, prefix="/GroupLink")
app.include_router(qucikcreate_router, prefix="/quick-chit")

@app.get("/health")
def health_check():
    return {"status": "ChitPro running"}

