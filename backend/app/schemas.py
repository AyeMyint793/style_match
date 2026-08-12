from pydantic import BaseModel, EmailStr
from typing import List, Optional, Dict

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    email: EmailStr
    new_password: str

class ProfileRequest(BaseModel):
    email: EmailStr
    name: str
    height: str
    size: str

class PreferenceRequest(BaseModel):
    email: EmailStr
    fit: str
    style: str

class ClothingSaveRequest(BaseModel):
    email: EmailStr
    image_path: str
    category: str
    subcategory: str
    occasion: str
    season: str
    color: str
    stylist_note: Optional[str] = None # Added for persistence

class GenerateOutfitRequest(BaseModel):
    email: EmailStr
    occasion: str
    season: str
    weather: str
    shown_item_ids: List[int] = []

class CompleteOutfitRequest(BaseModel):
    email: EmailStr
    selected_item: Dict
    weather: str

class TripPackingRequest(BaseModel):
    email: EmailStr
    destination: str
    days: int
    trip_type: str
    activities: str
    weather: str

class SaveOutfitRequest(BaseModel):
    email: EmailStr
    occasion: str
    season: str
    item_ids: List[int]
    description: str
