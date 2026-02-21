from pydantic import BaseModel
from typing import List
from uuid import UUID


class ChitMemberCreateRequest(BaseModel):
    name: str
    mobile_number: str | None = None
    member_no: int


class ChitMemberResponse(BaseModel):
    id: UUID
    name: str
    mobile_number: str | None
    member_no: int
    status: str


class ChitMemberListResponse(BaseModel):
    members: List[ChitMemberResponse]

class ChitMemberMultiCreateRequest(BaseModel):
    name: str
    mobile_number: str | None = None
    slot_count: int = 1

