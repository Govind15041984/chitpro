from pydantic import BaseModel
from typing import List
from uuid import UUID
from datetime import datetime


class MemberLedgerResponse(BaseModel):
    id: UUID
    chit_group_id: UUID
    member_id: UUID
    month_no: int

    installment_amount: int
    dividend_amount: int
    net_payable: int

    entry_type: str   # MONTHLY, PRIZE, ADJUSTMENT
    created_at: datetime


class MemberLedgerListResponse(BaseModel):
    entries: List[MemberLedgerResponse]

class MonthlyCollectionResponse(BaseModel):
    month: str
    total_collected: int
