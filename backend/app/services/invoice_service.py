from sqlalchemy.orm import Session
from datetime import datetime

from app.models.invoice_model import Invoice


def create_invoice(db: Session, admin_id: str, slab_code: str, amount: int, billing_month: str):
    invoice = Invoice(
        admin_id=admin_id,
        slab_code=slab_code,
        amount=amount,
        billing_month=billing_month,
        status="CREATED"
    )
    db.add(invoice)
    db.commit()
    db.refresh(invoice)
    return invoice


def get_invoices_for_admin(db: Session, admin_id: str):
    return db.query(Invoice).filter(
        Invoice.admin_id == admin_id
    ).order_by(Invoice.created_at.desc()).all()


def get_current_month_invoice(db: Session, admin_id: str, billing_month: str):
    return db.query(Invoice).filter(
        Invoice.admin_id == admin_id,
        Invoice.billing_month == billing_month
    ).first()


def mark_invoice_paid(db: Session, invoice_id: str, razorpay_payment_id: str):
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    if not invoice:
        return None

    invoice.status = "PAID"
    invoice.razorpay_payment_id = razorpay_payment_id
    invoice.paid_at = datetime.utcnow()

    db.commit()
    db.refresh(invoice)
    return invoice
