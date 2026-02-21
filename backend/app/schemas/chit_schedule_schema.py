# app/schemas/chit_schedule_schema.py
from pydantic import BaseModel
from datetime import datetime
from typing import Dict

class ScheduleCreateRequest(BaseModel):
    schedule_type: str
    rule: Dict
    start_date: datetime

class ScheduleResponse(BaseModel):
    id: str
    next_run: datetime
    schedule_type: str
    rule: Dict
