from pydantic import BaseModel
from typing import Dict,List
import os
from uuid import UUID
#print("🔥 SCHEMA FILE LOADED FROM:", os.path.abspath(__file__))

class ChitGroupCreateRequest(BaseModel):
    group_name: str
    chit_amount: int
    total_slots: int
    duration_months: int
    settings: Dict


class ChitGroupCreateResponse(BaseModel):
    id: str
    group_name: str
    lifecycle_status: str


class ChitGroupPreviewResponse(BaseModel):
    allowed: bool
    upgrade_required: bool
    message: str
    preview: dict | None


class ChitGroupListItem(BaseModel):
    id: str
    group_name: str
    chit_amount: int
    duration_months: int
    total_slots: int
    lifecycle_status: str

class CloseMonthResponse(BaseModel):
    chit_group_id: UUID
    closed_month_no: int
    new_current_month_no: int

    class Config:
        from_attributes = True


