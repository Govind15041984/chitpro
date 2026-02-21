from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.chit_group_model import ChitGroup 
from app.schemas.quick_create_schema import QuickChitRequest
from app.core.security import get_current_user
from datetime import datetime
from app.services.chit_group_service import build_prize_rule_for_kulukal

router = APIRouter(tags=["quick-chit-create"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()



@router.post("/create-active")
def create_active_chit(
    data: QuickChitRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    r = data.rules

    # --- VALIDATION ---
    if r.monthly_due_type == "Variable" and r.carry_forward:
        raise HTTPException(status_code=400, detail="Variable chits cannot carry forward reserve.")

    # --- PRIZE RULE (CANONICAL) ---
    if r.chit_type == "KULUKAL" and r.prize_mode == "CURVE":
        prize_rule = build_prize_rule_for_kulukal(
            chit_amount=data.chit_amount,
            months=data.duration_months
        )
    else:
        prize_rule = {
            "mode": r.prize_mode
        }

    # --- FOREMAN RULE (CANONICAL from legacy fields) ---
    if r.foreman_type == "FULL_MONTH":
        foreman_rule = {
            "mode": "FULL_MONTH",
            "when": "FIXED" if r.foreman_val > 0 else "ANY",
            "month_no": r.foreman_val if r.foreman_val > 0 else None
        }
    elif r.foreman_type == "PERCENTAGE":
        foreman_rule = {
            "mode": "PERCENTAGE",
            "percentage": r.foreman_val
        }
    else:
        foreman_rule = {
            "mode": r.foreman_type
        }

    # --- SETTINGS JSON (CANONICAL CONTRACT) ---
    settings_json = {
        "chit_type": r.chit_type,
        "monthly_due": {
            "type": r.monthly_due_type,
            "amount": r.installment_amount
        },
        "prize_rule": prize_rule,
        "foreman_rule": foreman_rule,
        "reserve_rule": {
            "carry_forward": r.carry_forward,
            "allow_multiple_auction": r.allow_multiple_auction,
            "use_for_final_payout": r.use_for_final_payout,
            "use_for_last_month_reduce": r.use_for_last_month_reduce
        },
        "dividend_rule": {
            "type": "DIVIDEND" if r.monthly_due_type == "Variable" else "NONE",
            "distribution": "VARIABLE" if r.monthly_due_type == "Variable" else "NONE"
        },
        "schedule_rule": {
            "frequency": r.frequency,
            "value": r.schedule_val
        }
    }

    try:
        new_group = ChitGroup(
            admin_id=current_user["id"],
            group_name=data.group_name,
            chit_amount=data.chit_amount,
            total_slots=data.total_slots,
            duration_months=data.duration_months,
            settings=settings_json,
            lifecycle_status="ACTIVE",
            current_month_no=0,
            created_at=datetime.utcnow()
        )
        db.add(new_group)
        db.commit()
        return {"id": str(new_group.id), "status": "ACTIVE"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))