import json
import os
from typing import List, Optional
from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from sqlalchemy import create_engine, Column, Integer, String, JSON, Boolean
from sqlalchemy.orm import sessionmaker, declarative_base, Session
import google.generativeai as genai
from dotenv import load_dotenv
from app.services.insight_service import InsightService

# Load Environment Variables
load_dotenv()
load_dotenv(dotenv_path="../.env")

# Configure Gemini
gemini_api_key = os.getenv("GEMINI_API_KEY")
if gemini_api_key:
    genai.configure(api_key=gemini_api_key)

app = FastAPI(title="Style Match Backend")

# CORS MIDDLEWARE
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# DATABASE SETUP
DATABASE_URL = "sqlite:///./users.db"
engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

# DATABASE TABLES
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=True)
    email = Column(String, unique=True, index=True)
    password = Column(String)
    age = Column(Integer, nullable=True)
    gender = Column(String, nullable=True)
    style = Column(String, nullable=True)
    height = Column(String, nullable=True)
    size = Column(String, nullable=True)

class UserPreference(Base):
    __tablename__ = "user_preferences"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    fit = Column(String, default="Regular")
    style = Column(String, default="Casual")

class ClothingItem(Base):
    __tablename__ = "clothing_items"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, index=True)
    image_path = Column(String)
    category = Column(String)
    subcategory = Column(String)
    occasion = Column(String)
    season = Column(String)
    color = Column(String)

class SavedOutfit(Base):
    __tablename__ = "saved_outfits"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, index=True)
    occasion = Column(String)
    season = Column(String)
    description = Column(String)
    items = Column(JSON)  # Stores detailed serialized items list

# CREATE TABLES
Base.metadata.create_all(bind=engine)

# PYDANTIC SCHEMAS
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

class GenerateOutfitRequest(BaseModel):
    email: EmailStr
    occasion: str
    season: str
    weather: str
    shown_item_ids: List[int] = []

class CompleteOutfitRequest(BaseModel):
    email: EmailStr
    selected_item: dict
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

# DB Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# GEMINI CALL HELPER
def call_gemini(prompt: str) -> str:
    if not gemini_api_key:
        raise HTTPException(
            status_code=500,
            detail="GEMINI_API_KEY not configured on server"
        )
    
    models = ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-1.5-flash"]
    last_err = None
    for model_name in models:
        try:
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(prompt)
            return response.text
        except Exception as e:
            last_err = e
            continue
    raise HTTPException(
        status_code=500,
        detail=f"Gemini API Error: {str(last_err)}"
    )

def clean_json_response(text: str) -> str:
    cleaned = text.strip()
    if cleaned.startswith("```json"):
        cleaned = cleaned[7:]
    elif cleaned.startswith("```"):
        cleaned = cleaned[3:]
    if cleaned.endswith("```"):
        cleaned = cleaned[:-3]
    return cleaned.strip()

# ROUTE HANDLERS
@app.get("/")
def home():
    return {"message": "Style Match Backend Running", "gemini_enabled": gemini_api_key is not None}

@app.post("/register")
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == data.email).first()
    if existing_user:
        return {"success": False, "message": "Email already registered"}

    user = User(email=data.email, password=data.password)
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"success": True, "message": "User registered successfully"}

@app.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        return {"success": False, "message": "User not found"}
    if user.password != data.password:
        return {"success": False, "message": "Incorrect password"}
    return {"success": True, "message": "Login successful"}

@app.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        return {"success": False, "message": "Email not found"}
    # Modular approach: In production, send a reset email here.
    return {"success": True, "message": "Account verified. Please set your new password."}

@app.post("/reset-password")
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        return {"success": False, "message": "User not found"}

    user.password = data.new_password
    db.commit()
    return {"success": True, "message": "Password reset successfully"}

@app.post("/save-profile")
def save_profile(profile: ProfileRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == profile.email).first()
    if not user:
        return {"success": False, "message": "User not found"}
    
    user.name = profile.name
    user.height = profile.height
    user.size = profile.size
    db.commit()
    return {"success": True, "message": "Profile saved successfully"}

@app.get("/get-profile")
def get_profile(email: str = Query(...), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == email).first()
    if not user:
        return {"success": False, "has_profile": False}
    
    # We consider profile complete if name and height are set
    has_profile = user.name is not None and user.height is not None
    return {
        "success": True,
        "has_profile": has_profile,
        "name": user.name or "",
        "height": user.height or "",
        "size": user.size or ""
    }

@app.post("/save-preferences")
def save_preferences(data: PreferenceRequest, db: Session = Depends(get_db)):
    pref = db.query(UserPreference).filter(UserPreference.email == data.email).first()
    if not pref:
        pref = UserPreference(email=data.email)
        db.add(pref)
    pref.fit = data.fit
    pref.style = data.style
    db.commit()
    return {"success": True, "message": "Preferences saved successfully"}

@app.get("/get-preferences")
def get_preferences(email: str = Query(...), db: Session = Depends(get_db)):
    pref = db.query(UserPreference).filter(UserPreference.email == email).first()
    if not pref:
        return {"success": True, "fit": "Regular", "style": "Casual"}
    return {"success": True, "fit": pref.fit, "style": pref.style}

# CLOTHING CRUD
@app.post("/save-clothes")
def save_clothes(item: ClothingSaveRequest, db: Session = Depends(get_db)):
    clothing = ClothingItem(
        email=item.email,
        image_path=item.image_path,
        category=item.category,
        subcategory=item.subcategory,
        occasion=item.occasion,
        season=item.season,
        color=item.color
    )
    db.add(clothing)
    db.commit()
    db.refresh(clothing)
    return {"success": True, "message": "Clothing item saved successfully", "id": clothing.id}

@app.get("/get-clothes")
def get_clothes(email: str = Query(...), db: Session = Depends(get_db)):
    items = db.query(ClothingItem).filter(ClothingItem.email == email).all()
    clothes_list = []
    for x in items:
        clothes_list.append({
            "id": x.id,
            "image_path": x.image_path,
            "category": x.category,
            "subcategory": x.subcategory or "",
            "occasion": x.occasion,
            "season": x.season,
            "color": x.color or ""
        })
    return {"success": True, "clothes": clothes_list}

@app.delete("/delete-clothes/{item_id}")
def delete_clothes(item_id: int, db: Session = Depends(get_db)):
    item = db.query(ClothingItem).filter(ClothingItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Clothing item not found")
    db.delete(item)
    db.commit()
    return {"success": True, "message": "Clothing item deleted successfully"}

# AI RECOMMENDATIONS ROUTING
@app.post("/generate-outfit")
def generate_outfit(data: GenerateOutfitRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    pref = db.query(UserPreference).filter(UserPreference.email == data.email).first()
    items = db.query(ClothingItem).filter(ClothingItem.email == data.email).all()
    
    if not items or len(items) < 2:
        return {
            "success": False,
            "message": "Add at least 2 items (e.g. Tops and Bottoms) to your wardrobe to generate outfits!"
        }
    
    pref_fit = pref.fit if pref else "Regular"
    pref_style = pref.style if pref else "Casual"
    
    clothes_json = json.dumps([{
        "id": x.id,
        "category": x.category,
        "subcategory": x.subcategory,
        "color": x.color,
        "season": x.season,
        "occasion": x.occasion,
        "image_path": x.image_path
    } for x in items], indent=2)
    
    prompt = f"""
    You are a professional fashion stylist. A client wants outfit recommendations from their personal wardrobe.

    User Profile:
    - Height: {user.height or "Unknown"} cm
    - Size: {user.size or "M"}
    - Fit preference: {pref_fit}
    - Style preference: {pref_style}

    Context:
    - Occasion: {data.occasion}
    - Season: {data.season}
    - Weather: {data.weather}

    Here is the user's personal wardrobe (in JSON format):
    {clothes_json}

    Please generate up to 3 different outfit combinations from the wardrobe that fit the occasion, season, weather, and style preferences.
    Try to avoid using items in this list: {data.shown_item_ids} if possible, to provide variety.

    For each outfit:
    1. Select appropriate items from the wardrobe. An outfit must contain a Top and a Bottom, OR a Single Dress, and optionally Shoes, Outerwear, and Accessories. Do NOT mix categories incorrectly.
    2. Provide a 1-2 sentence fashion rationale/explanation describing why this combination works for the weather/occasion and styling tips.

    Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
    {{
      "success": true,
      "outfits": [
        {{
          "outfit_number": 1,
          "description": "Fashion styling rationale...",
          "items": [
            {{
              "id": 12,
              "category": "Tops",
              "subcategory": "Shirt",
              "color": "Blue",
              "image_path": "https://..."
            }}
          ]
        }}
      ]
    }}

    If the wardrobe has too few matching items to make a valid outfit for this occasion/season/weather, return:
    {{
      "success": false,
      "message": "Add more clothing items matching this occasion/season to generate outfits."
    }}
    """
    
    try:
        response_text = call_gemini(prompt)
        cleaned = clean_json_response(response_text)
        result = json.loads(cleaned)
        return result
    except Exception as e:
        return {"success": False, "message": f"AI styling failed: {str(e)}"}

@app.post("/complete-outfit")
def complete_outfit(data: CompleteOutfitRequest, db: Session = Depends(get_db)):
    items = db.query(ClothingItem).filter(ClothingItem.email == data.email).all()
    if not items:
        return {"success": False, "message": "Wardrobe is empty"}

    clothes_json = json.dumps([{
        "id": x.id,
        "category": x.category,
        "subcategory": x.subcategory,
        "color": x.color,
        "season": x.season,
        "occasion": x.occasion,
        "image_path": x.image_path
    } for x in items], indent=2)

    prompt = f"""
    You are a professional fashion stylist. A client wants to complete a stylish outfit starting with a specific item from their wardrobe.

    Starting Item:
    {json.dumps(data.selected_item)}

    Here is the user's complete wardrobe (in JSON format):
    {clothes_json}

    Recommend matching items from the user's wardrobe to complete the outfit (e.g. if the starting item is a top, find matching bottoms, shoes, etc.).
    Provide a 1-2 sentence explanation of the completed look.

    Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
    {{
      "success": true,
      "outfit": {{
        "description": "Fashion rationale...",
        "items": [
          {{
            "id": 12,
            "category": "Tops",
            "subcategory": "Shirt",
            "color": "Blue",
            "image_path": "https://..."
          }}
        ]
      }}
    }}
    """

    try:
        response_text = call_gemini(prompt)
        cleaned = clean_json_response(response_text)
        result = json.loads(cleaned)
        return result
    except Exception as e:
        return {"success": False, "message": f"AI mapping failed: {str(e)}"}

@app.get("/analyze-wardrobe")
def analyze_wardrobe(email: str = Query(...), db: Session = Depends(get_db)):
    items = db.query(ClothingItem).filter(ClothingItem.email == email).all()
    
    # Compute stats regardless of item count
    stats = InsightService.compute_stats(items)
    
    if not items:
        return {
            "success": True,
            "stats": stats,
            "gaps": [{"suggestion": "Add tops and bottoms to your wardrobe to get started!"}]
        }

    clothes_json = json.dumps([{
        "category": x.category,
        "subcategory": x.subcategory,
        "color": x.color,
        "season": x.season,
        "occasion": x.occasion
    } for x in items], indent=2)

    prompt = f"""
    You are a fashion closet organizer and analyst.
    Here is the user's current wardrobe:
    {clothes_json}

    Identify styling gaps in this wardrobe (e.g. missing basic colors, missing outerwear, mismatch in top-to-bottom ratio, or missing categories).
    Provide 2 brief, actionable suggestions for what the user should add to their wardrobe next to maximize combinations.

    Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
    {{
      "success": true,
      "gaps": [
        {{
          "suggestion": "Detailed suggestion..."
        }}
      ]
    }}
    """

    try:
        response_text = call_gemini(prompt)
        cleaned = clean_json_response(response_text)
        result = json.loads(cleaned)
        result["stats"] = stats
        return result
    except Exception as e:
        return {"success": False, "message": str(e), "stats": stats}

@app.post("/trip-packing")
def trip_packing(data: TripPackingRequest, db: Session = Depends(get_db)):
    items = db.query(ClothingItem).filter(ClothingItem.email == data.email).all()
    if not items:
        return {"success": False, "message": "Wardrobe is empty. Add clothes first."}

    clothes_json = json.dumps([{
        "id": x.id,
        "category": x.category,
        "subcategory": x.subcategory,
        "color": x.color,
        "season": x.season,
        "occasion": x.occasion,
        "image_path": x.image_path
    } for x in items], indent=2)

    prompt = f"""
    You are an expert travel packing assistant.
    The user is planning a trip with the following details:
    - Destination: {data.destination}
    - Duration: {data.days} days
    - Trip Type: {data.trip_type}
    - Planned Activities: {data.activities}
    - Weather Forecast: {data.weather}

    Here is the user's wardrobe (in JSON format):
    {clothes_json}

    Create a travel packing plan:
    1. Select a subset of items from their wardrobe to pack. For each packed item, give a reason.
    2. Recommend outfits they can combine from these packed items. Return the combinations as string labels using the item subcategory and ID in parentheses, e.g., "Dinner Night: Blue Jeans (10) and White Shirt (6)".
    3. Identify "missing items" not in their wardrobe that they should buy or pack separately (e.g. if traveling to a cold city and they have no outerwear).
    4. Give one general packing tip.

    Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
    {{
      "success": true,
      "packing_list": [
        {{
          "item": {{
            "id": 1,
            "category": "Tops",
            "subcategory": "Shirt",
            "color": "White",
            "image_path": "https://..."
          }},
          "reason": "Perfect for casual sightseeing in mild weather."
        }}
      ],
      "combinations": [
        "Sightseeing: White Shirt (1) and Blue Jeans (2)"
      ],
      "missing_items": [
        "A heavy coat (it is cold at night)"
      ],
      "packing_tip": "Roll clothes instead of folding to maximize suitcase space."
    }}
    """

    try:
        response_text = call_gemini(prompt)
        cleaned = clean_json_response(response_text)
        result = json.loads(cleaned)
        return result
    except Exception as e:
        return {"success": False, "message": str(e)}

# SAVED OUTFITS ENDPOINTS
@app.post("/save-outfit")
def save_outfit(data: SaveOutfitRequest, db: Session = Depends(get_db)):
    # Query database for all selected items details
    items_list = db.query(ClothingItem).filter(
        ClothingItem.email == data.email,
        ClothingItem.id.in_(data.item_ids)
    ).all()
    
    serialized_items = [{
        "id": x.id,
        "category": x.category,
        "subcategory": x.subcategory,
        "color": x.color,
        "image_path": x.image_path
    } for x in items_list]
    
    outfit = SavedOutfit(
        email=data.email,
        occasion=data.occasion,
        season=data.season,
        description=data.description,
        items=serialized_items
    )
    db.add(outfit)
    db.commit()
    db.refresh(outfit)
    return {"success": True, "message": "Outfit saved successfully"}

@app.get("/get-saved-outfits")
def get_saved_outfits(email: str = Query(...), db: Session = Depends(get_db)):
    outfits = db.query(SavedOutfit).filter(SavedOutfit.email == email).all()
    result = []
    for x in outfits:
        result.append({
            "id": x.id,
            "occasion": x.occasion,
            "season": x.season,
            "description": x.description,
            "items": x.items
        })
    return {"success": True, "saved_outfits": result}

@app.delete("/delete-saved-outfit/{outfit_id}")
def delete_saved_outfit(outfit_id: int, db: Session = Depends(get_db)):
    outfit = db.query(SavedOutfit).filter(SavedOutfit.id == outfit_id).first()
    if not outfit:
        raise HTTPException(status_code=404, detail="Saved outfit not found")
    db.delete(outfit)
    db.commit()
    return {"success": True, "message": "Saved outfit deleted successfully"}
