from pydantic import BaseModel
from typing import List, Optional
from uuid import UUID
from datetime import datetime


class PlanSchema(BaseModel):
    slab_code: str           # e.g., "FREE", "BASIC_199"
    min_groups: int          # Usually 0
    max_groups: Optional[int] # This is your 'group_limit'
    amount_per_month: int    # This is your 'price_rupees' (The ₹1 test value)
    member_limit: int        # New: To show "Up to 20 members"


class CurrentSubscriptionResponse(BaseModel):
    slab_code: str | None
    status: str
    active_groups: int
    group_limit: int       # e.g., 5
    member_limit: int      # e.g., 20
    amount_per_month: int
    next_billing_date: Optional[datetime]



class UpgradePreviewRequest(BaseModel):
    projected_groups: int


class UpgradePreviewResponse(BaseModel):
    upgrade_required: bool
    current_slab: str
    new_slab: str
    current_groups: int
    projected_groups: int
    new_amount: int  # This will show '1' during your test!


class UpgradeRequest(BaseModel):
    target_slab: str   # S100, S300, S500


class UpgradeOrderResponse(BaseModel):
    order_id: str      # Razorpay Order ID (order_XXXXX)
    amount_paise: int  # The actual amount being charged
    slab_code: str     # Confirmation of the plan
    currency: str = "INR"

class ActivateSubscriptionRequest(BaseModel):
    slab_code: str


class ActivateSubscriptionResponse(BaseModel):
    status: str      # "ACTIVE"
    slab_code: str
    message: str     # "Plan activated successfully"

class VerifyPaymentRequest(BaseModel):
    order_id: str             # The 'rzp_order_id' from Flutter
    razorpay_payment_id: str  # The 'rzp_payment_id' from Flutter
    razorpay_signature: str   # The HMAC signature from Flutter

