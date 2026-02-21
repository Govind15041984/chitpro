import os
import razorpay
from dotenv import load_dotenv
from datetime import datetime
from datetime import timedelta
from sqlalchemy.orm import Session
from app.models.subscription_model import Subscription
from app.models.subscription_plans_model import SubscriptionPlan
from app.models.chit_group_model import ChitGroup

# 1. Force load the .env file BEFORE doing anything else
load_dotenv(override=True)

# 2. Get the keys
RAZORPAY_KEY_ID = os.getenv("RAZORPAY_KEY_ID")
RAZORPAY_KEY_SECRET = os.getenv("RAZORPAY_KEY_SECRET")

# 3. Fail-safe: This will stop the server from starting with empty keys
if not RAZORPAY_KEY_ID or not RAZORPAY_KEY_SECRET:
    raise ValueError("❌ CRITICAL: Razorpay keys missing from .env or .env not found!")

# 4. Initialize the client
client = razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))
print(f"✅ Razorpay Client Initialized: {RAZORPAY_KEY_ID[:12]}...")



#client = razorpay.Client(
#    auth=(os.getenv("RAZORPAY_KEY_ID"), os.getenv("RAZORPAY_KEY_SECRET"))
#)

SLABS = [
    {"code": "FREE", "min": 1, "max": 1, "amount": 0},
    {"code": "S100", "min": 2, "max": 3, "amount": 100},
    {"code": "S300", "min": 4, "max": 10, "amount": 300},
    {"code": "S500", "min": 11, "max": None, "amount": 500},
]


def calculate_slab(active_groups: int):
    for slab in SLABS:
        if slab["max"] is None:
            if active_groups >= slab["min"]:
                return slab
        else:
            if slab["min"] <= active_groups <= slab["max"]:
                return slab
    return SLABS[0]


def get_active_group_count(db: Session, admin_id):
    return db.query(ChitGroup).filter(
        ChitGroup.admin_id == admin_id,
        ChitGroup.lifecycle_status != "CLOSED"
    ).count()


def get_current_subscription(db: Session, admin_id: str):
    # We join Subscription with SubscriptionPlan to get the limits (group_limit, member_limit)
    sub = db.query(Subscription).filter(
        Subscription.admin_id == admin_id,
        Subscription.status == "ACTIVE"
    ).first()

    if not sub:
        return None

    # Fetch the plan details to get the limits
    plan = db.query(SubscriptionPlan).filter(SubscriptionPlan.slab_code == sub.slab_code).first()

    return {
        "slab_code": sub.slab_code,
        "status": sub.status,
        "amount_per_month": plan.price_rupees if plan else 0,
        "group_limit": plan.group_limit if plan else 1, # This was missing!
        "member_limit": plan.member_limit if plan else 10, # This was missing!
        "active_groups": 0, # You can calculate this later
        "next_billing_date": sub.cycle_end
    }


def preview_upgrade(db: Session, admin_id, projected_groups: int):
    # 1. Get live count
    current_groups = get_active_group_count(db, admin_id)
    
    # 2. Get current sub to know what they already have
    current_sub = get_current_subscription(db, admin_id)
    current_slab_code = current_sub.slab_code if current_sub else "FREE"

    # 3. Find the NEW plan required for the projected groups from DB
    # We look for the plan where group_limit is enough for projected_groups
    new_plan = db.query(SubscriptionPlan).filter(
        SubscriptionPlan.group_limit >= projected_groups,
        SubscriptionPlan.is_active == True
    ).order_by(SubscriptionPlan.group_limit.asc()).first()

    # 4. Compare Slab Codes instead of Amounts (Better for ₹1 test)
    upgrade_required = False
    if new_plan and current_slab_code != new_plan.slab_code:
        upgrade_required = True

    return {
        "upgrade_required": upgrade_required,
        "current_slab": current_slab_code,
        "new_slab": new_plan.slab_code if new_plan else "UNLIMITED",
        "current_groups": current_groups,
        "projected_groups": projected_groups,
        "new_amount": new_plan.price_rupees if new_plan else 0
    }


def activate_subscription(db: Session, admin_id: str, slab_code: str):
    """
    Force-activates a plan. Used for FREE plan or manual admin overrides.
    Does NOT use Razorpay.
    """
    # 1. Fetch Plan Details from the DB (The Source of Truth)
    plan = db.query(SubscriptionPlan).filter(
        SubscriptionPlan.slab_code == slab_code,
        SubscriptionPlan.is_active == True
    ).first()

    if not plan:
        raise Exception(f"Plan {slab_code} not found in database.")

    # 2. Safety Check: Deactivate any currently ACTIVE plan
    # This ensures the PIN Screen doesn't find two active plans
    db.query(Subscription).filter(
        Subscription.admin_id == admin_id,
        Subscription.status == "ACTIVE"
    ).update({"status": "INACTIVE"})

    # 3. Create the new Active record
    # Note: For FREE plans, we set a 100-year expiry
    expiry_days = 36500 if slab_code == "FREE" else 30
    
    new_sub = Subscription(
        admin_id=admin_id,
        slab_code=slab_code,
        status="ACTIVE",
        razorpay_payment_id="SYSTEM_ACTIVATED", # To distinguish from Razorpay
        cycle_start=datetime.utcnow(),
        cycle_end=datetime.utcnow() + timedelta(days=expiry_days)
    )

    db.add(new_sub)
    db.commit()
    db.refresh(new_sub)
    return new_sub

def create_subscription_order(db: Session, admin_id: str, slab_code: str):
    """Step 1: Look up price from DB and create Razorpay Order"""
    # 1. Look up plan in our 'Price Master' table
    plan = db.query(SubscriptionPlan).filter(
        SubscriptionPlan.slab_code == slab_code,
        SubscriptionPlan.is_active == True
    ).first()

    if not plan:
        raise Exception("Plan not found or currently inactive")

    # 2. Create the Razorpay Order (Amount in Paise)
    amount_in_paise = plan.price_rupees * 100
    razorpay_order = client.order.create({
        "amount": amount_in_paise,
        "currency": "INR",
        "payment_capture": 1
    })

    # 3. Save as 'CREATED' in our subscription table
    new_sub = Subscription(
        admin_id=admin_id,
        slab_code=slab_code,
        razorpay_order_id=razorpay_order['id'],
        status="CREATED"
    )
    db.add(new_sub)
    db.commit()
    db.refresh(new_sub)

    return {
        "order_id": razorpay_order['id'],
        "amount_paise": amount_in_paise,
        "slab_code": slab_code
    }

def verify_and_activate_subscription(db, order_id, payment_id, signature):
    try:
        # 1. Verify Signature (Razorpay Security)
        params_dict = {
            'razorpay_order_id': order_id,
            'razorpay_payment_id': payment_id,
            'razorpay_signature': signature
        }
        client.utility.verify_payment_signature(params_dict)

        # 2. Get the new subscription record
        new_sub = db.query(Subscription).filter(Subscription.razorpay_order_id == order_id).first()
        
        if new_sub:
            # 3. DEACTIVATE any existing active plans (like the FREE plan)
            db.query(Subscription).filter(
                Subscription.admin_id == new_sub.admin_id,
                Subscription.status == "ACTIVE",
                Subscription.id != new_sub.id  # Don't deactivate the one we are about to activate
            ).update({"status": "INACTIVE"})

            # 4. ACTIVATE the new paid plan
            new_sub.status = "ACTIVE"
            new_sub.razorpay_payment_id = payment_id
            new_sub.cycle_start = datetime.now()
            # Set cycle_end to 30 days from now
            new_sub.cycle_end = datetime.now() + timedelta(days=30)
            
            db.commit()
            return new_sub
            
    except Exception as e:
        db.rollback()
        print(f"Verification Error: {e}")
        return None

def get_all_plans(db: Session):
    """Fetches the 'Menu' of plans for the Frontend to display"""
    return db.query(SubscriptionPlan).filter(SubscriptionPlan.is_active == True).all()
