from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class InvoiceBase(BaseModel):
    id: str
    slab_code: str
    amount: int
    billing_month: str
    status: str  # CREATED, PAID, FAILED
    created_at: datetime
    paid_at: Optional[datetime]


class InvoiceResponse(InvoiceBase):
    pass


class InvoiceListResponse(BaseModel):
    invoices: List[InvoiceResponse]


class CreateInvoiceRequest(BaseModel):
    slab_code: str
    amount: int
    billing_month: str  # e.g. "2026-01"


class MarkInvoicePaidRequest(BaseModel):
    invoice_id: str
    razorpay_payment_id: str
