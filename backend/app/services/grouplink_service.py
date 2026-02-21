from sqlalchemy.orm import Session
from app.models.grouplink_model import GroupLink
from app.schemas.grouplink_schema import GroupLinkCreate

def get_links_by_group(db: Session, group_id: str):
    # Ensure we filter by the UUID correctly
    return db.query(GroupLink).filter(GroupLink.chit_group_id == group_id).all()

def update_or_create_link(db: Session, link_data: GroupLinkCreate):
    # Search for existing platform link for this specific group
    db_link = db.query(GroupLink).filter(
        GroupLink.chit_group_id == link_data.chit_group_id,
        GroupLink.platform == link_data.platform
    ).first()
    
    if db_link:
        db_link.link_url = link_data.link_url
        db_link.is_active = link_data.is_active
    else:
        # Pydantic v2 uses model_dump()
        db_link = GroupLink(**link_data.model_dump())
        db.add(db_link)
    
    db.commit()
    db.refresh(db_link)
    return db_link