from pydantic import BaseModel, HttpUrl
from uuid import UUID
from typing import Optional

class GroupLinkBase(BaseModel):
    platform: str  # "whatsapp", "telegram", "meeting"
    link_url: str
    is_active: bool = True

class GroupLinkCreate(GroupLinkBase):
    chit_group_id: UUID

class GroupLinkResponse(GroupLinkBase):
    id: int
    class Config:
        from_attributes = True