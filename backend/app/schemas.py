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
    gender: Optional[str] = "Female"
    avatar_url: Optional[str] = None

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

class ClothingUpdateRequest(BaseModel):
    id: int
    category: Optional[str] = None
    subcategory: Optional[str] = None
    occasion: Optional[str] = None
    season: Optional[str] = None
    color: Optional[str] = None
    stylist_note: Optional[str] = None

class BatchClothingItem(BaseModel):
    image_path: str
    category: str
    subcategory: str
    occasion: str
    season: str
    color: str
    stylist_note: Optional[str] = None

class BatchClothingSaveRequest(BaseModel):
    email: EmailStr
    items: List[BatchClothingItem]


class GenerateOutfitRequest(BaseModel):
    email: EmailStr
    occasion: str
    season: str
    weather: str
    previous_outfits: List[List[int]] = []
    style_item_ids: Optional[List[int]] = []

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
    start_date: Optional[str] = None
    end_date: Optional[str] = None

class RegenerateDayOutfitRequest(BaseModel):
    email: EmailStr
    destination: str
    day_number: int
    date: str
    activity: str
    weather: str
    trip_type: str
    previous_outfit_item_ids: List[int]
    other_days_outfits: List[List[int]]

class SaveOutfitRequest(BaseModel):
    email: EmailStr
    occasion: str
    season: str
    item_ids: List[int]
    description: str
    tags: Optional[List[str]] = []

class UpdateOutfitTagsRequest(BaseModel):
    id: int
    tags: List[str]
