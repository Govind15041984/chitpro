from pydantic import BaseModel, Field, constr

# 4 digit numeric PIN
PinType = constr(pattern=r"^\d{4}$")

class MobileCheckRequest(BaseModel):
    mobile_number: str = Field(..., example="9876543210")

class MobileCheckResponse(BaseModel):
    exists: bool

class AdminRegisterRequest(BaseModel):
    name: str
    mobile_number: str
    pin: PinType

class AdminLoginRequest(BaseModel):
    mobile_number: str
    pin: PinType

class AdminLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
