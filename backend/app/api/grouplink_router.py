from fastapi import APIRouter, Depends, HTTPException
from app.services.grouplink_service import (get_links_by_group, update_or_create_link)
from app.schemas.grouplink_schema import GroupLinkCreate
from app.core.database import SessionLocal
from app.core.security import create_access_token
from sqlalchemy.orm import Session

router = APIRouter(tags=["GroupLink"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/{group_id}")
def get_group_communication_hub(group_id: str, db: Session = Depends(get_db)):
    return get_links_by_group(db, group_id)


@router.post("/")
def save_group_link(link_data: GroupLinkCreate,db: Session = Depends(get_db)):
    """
    Creates a new group link or updates an existing one for the same platform.
    """
    try:
        return update_or_create_link(db, link_data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))