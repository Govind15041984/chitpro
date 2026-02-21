from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class CreatePaymentOrderRequest(BaseModel):
    slab_code: str      # S100, S300, S500
    amount: int        # 100, 300, 500


class CreatePaymentOrderResponse(BaseModel):
    order_id: str
    provider: str      # RAZORPAY
    amount: int
    currency: str
    payment_url: Optional[str]


class PaymentVerifyRequest(BaseModel):
    order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


class PaymentStatusResponse(BaseModel):
    status: str        # PAID, FAILED
    slab_code: str
    amount: int
    paid_at: Optional[datetime]
