from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, case
from app.core.database import SessionLocal
from app.core.security import get_current_user
from app.models.chit_group_model import ChitGroup
from app.models.member_ledger_model import MemberLedger
from app.models.subscription_model import Subscription
from app.models.subscription_plans_model import SubscriptionPlan
from app.models.grouplink_model import GroupLink
from app.services.auction_round_service import get_next_live_auction
from app.api.member_ledger_router import get_monthly_collection

router = APIRouter(tags=["Dashboard"])

def get_db():
    db = SessionLocal() 
    try:
        yield db
    finally:
        db.close()

@router.get("", summary="Get Admin Dashboard")
def get_dashboard(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    admin_id = current_user["id"]

    # 1. Admin info
    name_in_db = current_user.get("name")
    admin_name = name_in_db if name_in_db and str(name_in_db).strip() else current_user.get("mobile_number", "Admin")
    avatar_letter = admin_name[0].upper()

    # 2. Groups Fetching
    groups = db.query(ChitGroup).filter(
        ChitGroup.admin_id == admin_id,
        ChitGroup.lifecycle_status != "CLOSED"
    ).all()

    group_list = []
    for g in groups:
        whatsapp_link = db.query(GroupLink).filter(
            GroupLink.chit_group_id == g.id,
            GroupLink.platform == "whatsapp",
            GroupLink.is_active == True
        ).first()

        group_list.append({
            "id": str(g.id),
            "group_name": g.group_name,
            "chit_amount": g.chit_amount,
            "duration_months": g.duration_months,
            "total_slots": g.total_slots,
            "status": g.lifecycle_status,
            "current_month": g.current_month_no,
            "next_run_date": g.next_run_date.isoformat() if g.next_run_date else None,
            "whatsapp_group_link": whatsapp_link.link_url if whatsapp_link else None,
        })

    # 3. Financial summary
    financials = db.query(
        func.sum(case((MemberLedger.payment_status == 'PAID', MemberLedger.net_payable), else_=0)).label("collected"),
        func.sum(case((MemberLedger.payment_status == 'PENDING', MemberLedger.net_payable), else_=0)).label("pending")
    ).select_from(ChitGroup).join(
        MemberLedger, MemberLedger.chit_group_id == ChitGroup.id
    ).filter(
        ChitGroup.admin_id == admin_id
    ).first()

    # 4. FULLY DYNAMIC SUBSCRIPTION LOGIC
    # First, look for an ACTIVE paid subscription
    active_sub = db.query(Subscription).filter(
        Subscription.admin_id == admin_id,
        Subscription.status == "ACTIVE"
    ).order_by(Subscription.created_at.desc()).first()

    if active_sub:
        # User has a paid plan
        plan_code = active_sub.slab_code
    else:
        # Fallback to FREE
        plan_code = "FREE"

    # Fetch the actual limits for whatever plan_code we found
    plan_details = db.query(SubscriptionPlan).filter(
        SubscriptionPlan.slab_code == plan_code
    ).first()

    # Final protection: if even the FREE plan is missing from DB, use safe defaults
    group_limit = plan_details.group_limit if plan_details else 1
    member_limit = plan_details.member_limit if plan_details else 10

    # 5. Live auction
    live_auction = get_next_live_auction(db, admin_id)

    return {
        "admin": {
            "id": admin_id,
            "name": admin_name,
            "avatar_letter": avatar_letter,
            "plan": plan_code
        },
        "summary": {
            "active_chits_count": len(group_list),
            "monthly_collected": financials.collected or 0,
            "monthly_pending": financials.pending or 0,
            "total_groups_value": sum(g.chit_amount for g in groups),
            "group_limit": group_limit,
            "member_limit": member_limit
        },
        "groups": group_list,
        "live_auction": live_auction
    }

