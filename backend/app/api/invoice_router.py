from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from uuid import uuid4
from app.core.database import SessionLocal
from app.schemas.invoice_schema import (
    InvoiceResponse,
    InvoiceListResponse,
    MarkInvoicePaidRequest  
)
from app.services.invoice_service import (
    get_invoices_for_admin,
    get_current_month_invoice,
    mark_invoice_paid
)
from app.core.security import get_current_user

router = APIRouter(tags=["Invoices"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("", response_model=InvoiceListResponse)
def list_invoices(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    admin_id = current_user["id"]
    invoices = get_invoices_for_admin(db, admin_id)
    return {"invoices": invoices}


@router.get("/current", response_model=InvoiceResponse)
def current_invoice(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    admin_id = current_user["id"]
    billing_month = datetime.utcnow().strftime("%Y-%m")

    invoice = get_current_month_invoice(db, admin_id, billing_month)

    if not invoice:
        # Virtual invoice for FREE plan
        return {
            "id": str(uuid4()),               # fake but valid id
            "slab_code": "FREE",
            "amount": 0,
            "billing_month": billing_month,
            "status": "PAID",
            "created_at": datetime.utcnow(), # required by schema
            "paid_at": None
        }

    return invoice



@router.post("/mark-paid", response_model=InvoiceResponse)
def mark_paid(
    data: MarkInvoicePaidRequest,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    admin_id = current_user["id"]
    invoice = mark_invoice_paid(db, data.invoice_id, data.razorpay_payment_id)

    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    # optional safety: ensure invoice belongs to same admin
    if str(invoice.admin_id) != str(admin_id):
        raise HTTPException(status_code=403, detail="Not allowed")

    return invoice
