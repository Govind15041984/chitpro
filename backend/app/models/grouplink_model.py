import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, Integer, ForeignKey, Boolean
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base

class GroupLink(Base):
    __tablename__ = "group_links"
    id = Column(Integer, primary_key=True)
    chit_group_id = Column(UUID, ForeignKey("chit_groups.id"))
    platform = Column(String) # "whatsapp", "telegram", "meeting"
    link_url = Column(String)
    is_active = Column(Boolean, default=True)       