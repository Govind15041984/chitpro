from sqlalchemy.orm import Session
from passlib.context import CryptContext

from app.models.admin_model import Admin

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_pin(pin: str) -> str:
    return pwd_context.hash(pin)


def verify_pin(plain_pin: str, hashed_pin: str) -> bool:
    return pwd_context.verify(plain_pin, hashed_pin)


def get_admin_by_mobile(db: Session, mobile_number: str):
    return db.query(Admin).filter(Admin.mobile_number == mobile_number).first()


def create_admin(db: Session, name: str, mobile_number: str, pin: str):
    pin_hash = hash_pin(pin)
    admin = Admin(
        name=name,
        mobile_number=mobile_number,
        pin_hash=pin_hash
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    return admin


def authenticate_admin(db: Session, mobile_number: str, pin: str):
    admin = get_admin_by_mobile(db, mobile_number)
    if not admin:
        print(f"❌ User {mobile_number} not found in DB")
        return None
        
    is_valid = verify_pin(pin, admin.pin_hash)
    print(f"🔍 Checking PIN for {mobile_number}: Input='{pin}', Hash='{admin.pin_hash}' -> Result: {is_valid}")
    
    if not is_valid:
        return None
    return admin
