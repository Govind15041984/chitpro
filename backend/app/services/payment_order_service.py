from sqlalchemy.orm import Session
from datetime import datetime

from app.models.payment_order_model import PaymentOrder
from app.schemas.payment_order_schema import CreatePaymentOrderRequest


def create_payment_order(db: Session, admin_id: str, slab_code: str, amount: int, provider_order_id: str):
    payment = PaymentOrder(
        admin_id=admin_id,
        slab_code=slab_code,
        amount=amount,
        provider="RAZORPAY",
        provider_order_id=provider_order_id,
        status="CREATED"
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return payment


def mark_payment_success(db: Session, provider_order_id: str, razorpay_payment_id: str):
    payment = db.query(PaymentOrder).filter(
        PaymentOrder.provider_order_id == provider_order_id
    ).first()

    if not payment:
        return None

    payment.status = "PAID"
    payment.paid_at = datetime.utcnow()
    payment.razorpay_payment_id = razorpay_payment_id

    db.commit()
    db.refresh(payment)
    return payment


def mark_payment_failed(db: Session, provider_order_id: str):
    payment = db.query(PaymentOrder).filter(
        PaymentOrder.provider_order_id == provider_order_id
    ).first()

    if not payment:
        return None

    payment.status = "FAILED"
    db.commit()
    db.refresh(payment)
    return payment
