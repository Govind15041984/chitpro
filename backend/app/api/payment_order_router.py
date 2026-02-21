from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import uuid

from app.core.database import SessionLocal
from app.schemas.payment_order_schema import (
    CreatePaymentOrderRequest,
    CreatePaymentOrderResponse,
    PaymentVerifyRequest,
    PaymentStatusResponse
)
from app.services.payment_order_service import (
    create_payment_order,
    mark_payment_success
)

router = APIRouter(tags=["Payments"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/create-order", response_model=CreatePaymentOrderResponse)
def create_order(data: CreatePaymentOrderRequest, admin_id: str, db: Session = Depends(get_db)):
    # Simulate Razorpay order id (later real Razorpay integration)
    provider_order_id = f"order_{uuid.uuid4().hex}"

    payment = create_payment_order(
        db=db,
        admin_id=admin_id,
        slab_code=data.slab_code,
        amount=data.amount,
        provider_order_id=provider_order_id
    )

    return {
        "order_id": payment.provider_order_id,
        "provider": "RAZORPAY",
        "amount": payment.amount,
        "currency": "INR",
        "payment_url": None  # later real Razorpay checkout URL
    }


@router.post("/verify", response_model=PaymentStatusResponse)
def verify_payment(data: PaymentVerifyRequest, db: Session = Depends(get_db)):
    # Later: verify Razorpay signature
    payment = mark_payment_success(
        db=db,
        provider_order_id=data.order_id,
        razorpay_payment_id=data.razorpay_payment_id
    )

    if not payment:
        raise HTTPException(status_code=404, detail="Payment order not found")

    return {
        "status": "PAID",
        "slab_code": payment.slab_code,
        "amount": payment.amount,
        "paid_at": payment.paid_at
    }
