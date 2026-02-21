import os
import razorpay
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.core.database import SessionLocal
from app.core.security import get_current_user
from app.schemas.subscription_schema import (
    PlanSchema, 
    CurrentSubscriptionResponse, 
    UpgradePreviewRequest, 
    UpgradePreviewResponse, 
    ActivateSubscriptionRequest, 
    ActivateSubscriptionResponse,
    # Ensure VerifyPaymentRequest is in your schema file
    VerifyPaymentRequest 
)
from app.services.subscription_service import (
    get_all_plans, 
    create_subscription_order, 
    verify_and_activate_subscription,
    get_current_subscription, 
    get_active_group_count, 
    preview_upgrade,
    activate_subscription
)

router = APIRouter(tags=["Subscription"])


# Database Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- 1. DISCOVERY ENDPOINTS ---

@router.get("/plans")
def list_plans(db: Session = Depends(get_db)):
    plans = get_all_plans(db)
    # We manually map DB fields to the Schema fields here
    return [
        {
            "slab_code": p.slab_code,
            "min_groups": 0,
            "max_groups": p.group_limit,    # Mapping DB to Schema
            "amount_per_month": p.price_rupees, # The ₹1 test price
            "member_limit": p.member_limit
        }
        for p in plans
    ]

@router.post("/preview-upgrade", response_model=UpgradePreviewResponse)
def preview(
    data: UpgradePreviewRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    PURPOSE: Calculates if an upgrade is needed based on projected group counts.
    USE CASE: Shows a 'Plan exceeds limit' warning in the App.
    """
    admin_id = current_user["id"]
    return preview_upgrade(db, admin_id, data.projected_groups)


# --- 2. STATUS ENDPOINT (CRITICAL FOR PIN SCREEN) ---

@router.get("/current", response_model=CurrentSubscriptionResponse)
def current_subscription(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    PURPOSE: Check the Admin's active plan and limits.
    """
    admin_id = current_user["id"]
    
    # This now returns a DICTIONARY from subscription_service.py
    sub_data = get_current_subscription(db, admin_id)
    
    # 1. Handle Case: No Subscription Found
    if not sub_data:
        return {
            "slab_code": None,
            "status": "INACTIVE",
            "amount_per_month": 0,
            "group_limit": 1,   # Default values to satisfy Pydantic
            "member_limit": 10, 
            "active_groups": 0,
            "next_billing_date": None
        }

    # 2. Get the real count of groups the admin has created
    active_groups_count = get_active_group_count(db, admin_id)
    
    # 3. Return the data using Dictionary keys [] instead of dot notation .
    return {
        "slab_code": sub_data["slab_code"],
        "status": sub_data["status"],
        "amount_per_month": sub_data["amount_per_month"],
        "group_limit": sub_data["group_limit"],      # Required by your schema
        "member_limit": sub_data["member_limit"],    # Required by your schema
        "active_groups": active_groups_count,
        "next_billing_date": sub_data["next_billing_date"]
    }


# --- 3. ACTION ENDPOINTS (PAYMENT & ACTIVATION) ---

@router.post("/activate", response_model=ActivateSubscriptionResponse)
def activate(
    data: ActivateSubscriptionRequest, 
    current_user: dict = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    """
    PURPOSE: Direct activation without payment (e.g., for FREE plan).
    USE CASE: Called during registration or for free tier selection.
    """
    admin_id = current_user["id"]
    return activate_subscription(db, admin_id, data.slab_code)

@router.post("/create-order")
def create_order(
    data: ActivateSubscriptionRequest, 
    current_user = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    """
    PURPOSE: Initiates the Razorpay Live Payment process.
    USE CASE: User clicks a paid plan; returns the Real Order ID for ₹1 test.
    """
    try:
        return create_subscription_order(db, admin_id=current_user["id"], slab_code=data.slab_code)
    except Exception as e:
        print(f"RAZORPAY ERROR: {e}") #
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/verify")
def verify_payment(
    data: VerifyPaymentRequest, 
    db: Session = Depends(get_db)
):
    """
    PURPOSE: Securely verifies the Razorpay signature and unlocks the plan.
    USE CASE: Called by Flutter after a successful ₹1 transaction.
    """
    subscription = verify_and_activate_subscription(
        db, 
        order_id=data.order_id, 
        payment_id=data.razorpay_payment_id, 
        signature=data.razorpay_signature
    )
    
    if not subscription:
        raise HTTPException(status_code=400, detail="Payment verification failed")
        
    return {"status": "SUCCESS", "message": f"Plan {subscription.slab_code} activated"}

@router.get("/config")
def get_config():
    return {
        "key_id": os.getenv("RAZORPAY_KEY_ID"), # Flutter needs this to open UI
        "user_contact": "8884755583", 
        "user_email": "test@example.com"
    }