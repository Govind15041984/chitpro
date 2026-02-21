from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.schemas.admin_schema import (
    MobileCheckRequest,
    MobileCheckResponse,
    AdminRegisterRequest,
    AdminLoginRequest,
    AdminLoginResponse
)
from app.services.admin_service import (
    get_admin_by_mobile,
    create_admin,
    authenticate_admin
)
from app.core.security import create_access_token

router = APIRouter(tags=["Admin"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/check-mobile", response_model=MobileCheckResponse)
def check_mobile(data: MobileCheckRequest, db: Session = Depends(get_db)):
    admin = get_admin_by_mobile(db, data.mobile_number)
    return {"exists": True if admin else False}


@router.post("/register", response_model=AdminLoginResponse)
def register(data: AdminRegisterRequest, db: Session = Depends(get_db)):
    # 1. Check if user already exists
    existing = get_admin_by_mobile(db, data.mobile_number)
    if existing:
        raise HTTPException(status_code=400, detail="Mobile number already registered")

    # 2. Create the Admin record
    admin = create_admin(db, data.name, data.mobile_number, data.pin)

    # 3. AUTO-ACTIVATE FREE PLAN
    # We import this here to avoid potential circular import issues 
    # and call your existing service logic.
    from app.services.subscription_service import activate_subscription
    
    try:
        # We pass the admin.id and the "FREE" slab_code
        activate_subscription(db, str(admin.id), "FREE")
    except Exception as e:
        # We log the error but don't fail the registration 
        # because the user is already created in the DB.
        print(f"⚠️ Subscription auto-activation failed for {admin.id}: {e}")

    # 4. Generate the token
    token = create_access_token({"sub": str(admin.id), "role": "ADMIN"})

    return {"access_token": token}


@router.post("/login", response_model=AdminLoginResponse)
def login(data: AdminLoginRequest, db: Session = Depends(get_db)):
    admin = authenticate_admin(db, data.mobile_number, data.pin)
    if not admin:
        raise HTTPException(status_code=401, detail="Invalid mobile or PIN")

    #token = create_access_token({"sub": str(admin.id)})
    token = create_access_token({"sub": str(admin.id), "role": "ADMIN"})
    return {"access_token": token}
    