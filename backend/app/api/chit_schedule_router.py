# app/routers/chit_schedule_router.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.chit_schedule_model import ChitSchedule
from app.services.chit_schedule_service import compute_next_run
from app.schemas.chit_schedule_schema import ScheduleCreateRequest
from datetime import datetime

router = APIRouter(tags=["Chit Schedule"])

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

@router.post("/{chit_group_id}")
def create_schedule(chit_group_id: str, data: ScheduleCreateRequest, db: Session = Depends(get_db)):
    next_run = compute_next_run(data.schedule_type, data.rule, data.start_date)

    schedule = ChitSchedule(
        chit_group_id=chit_group_id,
        schedule_type=data.schedule_type,
        rule=data.rule,
        start_date=data.start_date,
        next_run=next_run
    )
    db.add(schedule)
    db.commit()
    db.refresh(schedule)
    return schedule
