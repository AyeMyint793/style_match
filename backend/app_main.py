import io
import json
import os
import traceback
from typing import List, Optional
from fastapi import FastAPI, Depends, HTTPException, Query, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from sqlalchemy import create_engine, Column, Integer, String, JSON, Boolean
from sqlalchemy.orm import sessionmaker, declarative_base, Session
import google.generativeai as genai
from dotenv import load_dotenv
from app.services.insight_service import InsightService
from app.services.image_service import ImageService
from app.services.ai_service import AIService
import cloudinary
import cloudinary.uploader
from PIL import Image



# Load Environment Variables
load_dotenv()
load_dotenv(dotenv_path="../.env")

# Configure Gemini
gemini_api_key = os.getenv("GEMINI_API_KEY")
if gemini_api_key:
    genai.configure(api_key=gemini_api_key)

# Configure Cloudinary
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)

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
    avatar_url = Column(String, nullable=True)

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
    tags = Column(JSON, nullable=True)

# CREATE TABLES
Base.metadata.create_all(bind=engine)

# Add tags and avatar_url columns if they do not exist
try:
    from sqlalchemy import text
    with engine.connect() as conn:
        # Check saved_outfits table
        result = conn.execute(text("PRAGMA table_info(saved_outfits)"))
        columns = [row[1] for row in result.fetchall()]
        if "tags" not in columns:
            conn.execute(text("ALTER TABLE saved_outfits ADD COLUMN tags TEXT"))
            conn.commit()
            print("Successfully added 'tags' column to 'saved_outfits' table.")
        
        # Check users table
        result_users = conn.execute(text("PRAGMA table_info(users)"))
        columns_users = [row[1] for row in result_users.fetchall()]
        if "avatar_url" not in columns_users:
            conn.execute(text("ALTER TABLE users ADD COLUMN avatar_url TEXT"))
            conn.commit()
            print("Successfully added 'avatar_url' column to 'users' table.")
except Exception as e:
    print(f"Error altering database tables in app_main.py: {e}")

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
    
    models = ["gemini-3.6-flash", "gemini-3.7-flash", "gemini-3.5-flash", "gemini-flash-latest", "gemini-flash-lite-latest"]
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
    user.gender = profile.gender
    user.avatar_url = profile.avatar_url
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
        "size": user.size or "",
        "gender": user.gender or "Female",
        "avatar_url": user.avatar_url or ""
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
@app.post("/process-image")
async def process_image(file: UploadFile = File(...)):
    try:
        raw_bytes = await file.read()
        mime = file.content_type or "image/jpeg"
        detection = AIService.detect_multiple_clothes(raw_bytes, mime_type=mime)

        if detection.get("success") and detection.get("items"):
            item = detection["items"][0]
            master_img = ImageService.load_image_from_bytes(raw_bytes)
            processed_bytes = ImageService.process_multi_item_crop(
                master_img,
                item.get("box_2d", [0, 0, 1000, 1000]),
                category=item.get("category", "Tops")
            )
            tags = {
                "is_clothing": True,
                "confidence": item.get("confidence", "high"),
                "category": item.get("category", "Tops"),
                "subcategory": item.get("subcategory", "Garment"),
                "occasion": item.get("occasion", "Casual"),
                "season": item.get("season", "All Season"),
                "color": item.get("color", "Mixed"),
                "stylist_note": item.get("stylist_note", "")
            }
        else:
            tags = AIService.detect_clothing(raw_bytes)
            if not tags or str(tags.get("is_clothing")).lower() != "true":
                return {
                    "success": False,
                    "message": "No clear clothing item detected. Try placing the garment away from busy bedding or background patterns."
                }
            processed_bytes = ImageService.process_clothing_image(
                raw_bytes,
                category=tags.get("category", "Tops")
            )

        upload_result = cloudinary.uploader.upload(
            processed_bytes,
            folder="style_match_clothes",
            format="png"
        )
        secure_url = upload_result.get("secure_url")
        if not secure_url:
            raise HTTPException(status_code=500, detail="Cloudinary upload failed")
        
        return {
            "success": True,
            "image_url": secure_url,
            "tags": tags
        }
    except Exception as e:
        print(f"Error processing image in route: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/process-multi-image")
async def process_multi_image(file: UploadFile = File(...)):
    try:
        raw_bytes = await file.read()
        detection = AIService.detect_multiple_clothes(raw_bytes, mime_type=file.content_type or "image/jpeg")
        
        if not detection.get("success") or not detection.get("items"):
            try:
                single_tags = AIService.detect_clothing(raw_bytes)
                is_single_clothing = str(single_tags.get("is_clothing")).lower() == "true"
                is_confident = str(single_tags.get("confidence", "low")).lower() != "low"
                if single_tags and is_single_clothing and is_confident:
                    single_png_bytes = ImageService.process_clothing_image(
                        raw_bytes,
                        category=single_tags.get("category", "Tops")
                    )
                    upload_result = cloudinary.uploader.upload(
                        single_png_bytes,
                        folder="style_match_clothes",
                        format="png"
                    )
                    secure_url = upload_result.get("secure_url")
                    if secure_url:
                        return {
                            "success": True,
                            "items_count": 1,
                            "items": [{
                                "image_path": secure_url,
                                "category": single_tags.get("category", "Tops"),
                                "subcategory": single_tags.get("subcategory", "Garment"),
                                "color": single_tags.get("color", "Mixed"),
                                "occasion": single_tags.get("occasion", "Casual"),
                                "season": single_tags.get("season", "All Season"),
                                "stylist_note": single_tags.get("stylist_note", ""),
                                "box_2d": [0, 0, 1000, 1000]
                            }]
                        }
            except Exception as fe:
                print(f"Fallback single item detection failed: {fe}")

            return {
                "success": False,
                "message": detection.get("message", "No clear clothing items detected in this photo.")
            }

        detected_items = detection["items"]
        master_img = ImageService.load_image_from_bytes(raw_bytes)
        
        def _process_single_crop(item):
            box = item.get("box_2d")
            if not box or len(box) != 4:
                return None
            try:
                item_png_bytes = ImageService.process_multi_item_crop(
                    master_img,
                    box,
                    category=item.get("category", "Tops")
                )
                upload_result = cloudinary.uploader.upload(
                    item_png_bytes,
                    folder="style_match_clothes",
                    format="png"
                )
                secure_url = upload_result.get("secure_url")
                if secure_url:
                    return {
                        "image_path": secure_url,
                        "category": item.get("category", "Tops"),
                        "subcategory": item.get("subcategory", item.get("category", "Clothing Item")),
                        "color": item.get("color", "Mixed"),
                        "pattern": item.get("pattern", "Solid"),
                        "confidence": item.get("confidence", "high"),
                        "occasion": item.get("occasion", "Casual"),
                        "season": item.get("season", "All Season"),
                        "stylist_note": item.get("stylist_note", ""),
                        "box_2d": box
                    }
            except Exception as ex:
                print(f"Error processing single crop: {ex}")
                traceback.print_exc()
            return None

        with concurrent.futures.ThreadPoolExecutor(max_workers=min(len(detected_items), 4)) as executor:
            results = list(executor.map(_process_single_crop, detected_items))

        processed_items = [r for r in results if r is not None]

        if not processed_items:
            return {
                "success": False,
                "message": "Could not isolate garments from the photo. Try laying them out with more space."
            }

        return {
            "success": True,
            "items_count": len(processed_items),
            "items": processed_items
        }
    except Exception as e:
        print(f"Error in process_multi_image route: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/batch-save-clothes")
def batch_save_clothes(data: BatchClothingSaveRequest, db: Session = Depends(get_db)):
    try:
        saved_ids = []
        for item in data.items:
            clothing = ClothingItem(
                email=data.email,
                image_path=item.image_path,
                category=item.category,
                subcategory=item.subcategory,
                occasion=item.occasion,
                season=item.season,
                color=item.color
            )
            db.add(clothing)
            db.flush()
            saved_ids.append(clothing.id)

        db.commit()
        return {
            "success": True,
            "message": f"Successfully saved {len(saved_ids)} clothing items to wardrobe!",
            "saved_ids": saved_ids
        }
    except Exception as e:
        db.rollback()
        print("batch_save_clothes failed", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/save-clothes")
def save_clothes(item: ClothingSaveRequest, db: Session = Depends(get_db)):
    category_map = {
        't-shirt': 'Tops', 'tshirt': 'Tops', 'shirt': 'Tops', 'top': 'Tops', 'tops': 'Tops',
        'jeans': 'Bottoms', 'trousers': 'Bottoms', 'pants': 'Bottoms', 'bottom': 'Bottoms', 'bottoms': 'Bottoms',
        'dress': 'Dress', 'dresses': 'Dress',
        'shoe': 'Shoes', 'shoes': 'Shoes', 'sneakers': 'Shoes', 'boots': 'Shoes',
        'jacket': 'Outerwear', 'coat': 'Outerwear', 'outerwear': 'Outerwear',
        'bag': 'Accessories', 'handbag': 'Accessories', 'purse': 'Accessories', 'accessories': 'Accessories'
    }
    season_map = {'summer': 'Summer', 'winter': 'Winter', 'all season': 'All Season'}
    cat = (item.category or '').strip()
    canonical_category = category_map.get(cat.lower(), item.category)
    season_val = (item.season or '').strip()
    canonical_season = season_map.get(season_val.lower(), item.season)

    clothing = ClothingItem(
        email=item.email,
        image_path=item.image_path,
        category=canonical_category,
        subcategory=item.subcategory,
        occasion=item.occasion,
        season=canonical_season,
        color=item.color or '',
        stylist_note=item.stylist_note
    )
    db.add(clothing)
    db.commit()
    db.refresh(clothing)
    return {"success": True, "message": "Clothing item saved successfully", "id": clothing.id}

@app.post("/update-clothes")
def update_clothes(data: ClothingUpdateRequest, db: Session = Depends(get_db)):
    clothing = db.query(ClothingItem).filter(ClothingItem.id == data.id).first()
    if not clothing:
        raise HTTPException(status_code=404, detail="Clothing item not found")
    
    category_map = {
        't-shirt': 'Tops', 'tshirt': 'Tops', 'shirt': 'Tops', 'top': 'Tops', 'tops': 'Tops',
        'jeans': 'Bottoms', 'trousers': 'Bottoms', 'pants': 'Bottoms', 'bottom': 'Bottoms', 'bottoms': 'Bottoms',
        'dress': 'Dress', 'dresses': 'Dress',
        'shoe': 'Shoes', 'shoes': 'Shoes', 'sneakers': 'Shoes', 'boots': 'Shoes',
        'jacket': 'Outerwear', 'coat': 'Outerwear', 'outerwear': 'Outerwear',
        'bag': 'Accessories', 'handbag': 'Accessories', 'purse': 'Accessories', 'accessories': 'Accessories'
    }
    season_map = {'summer': 'Summer', 'winter': 'Winter', 'all season': 'All Season'}

    if data.category is not None:
        cat = data.category.strip()
        clothing.category = category_map.get(cat.lower(), data.category)
    if data.subcategory is not None:
        clothing.subcategory = data.subcategory
    if data.occasion is not None:
        clothing.occasion = data.occasion
    if data.season is not None:
        season_val = data.season.strip()
        clothing.season = season_map.get(season_val.lower(), data.season)
    if data.color is not None:
        clothing.color = data.color
    if data.stylist_note is not None:
        clothing.stylist_note = data.stylist_note

    db.commit()
    db.refresh(clothing)
    return {"success": True, "message": "Clothing item updated successfully", "id": clothing.id}

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

    date_prompt = ""
    if data.start_date and data.end_date:
        date_prompt = f"- Trip Dates: From {data.start_date} to {data.end_date}\n"

    prompt = f"""
    You are a creative, professional personal fashion stylist and expert travel packing assistant specializing in modern, high-end, Pinterest-style aesthetics.
    Your goal is to create a personalized day-by-day outfit plan for a user's trip using ONLY their wardrobe items.

    The user is planning a trip with the following details:
    - Destination: {data.destination}
    - Duration: {data.days} days
    {date_prompt}- Trip Type: {data.trip_type}
    - Planned Activities: {data.activities}
    - Weather Forecast: {data.weather}

    Here is the user's wardrobe (in JSON format):
    {clothes_json}

    Capsule Styling & Smart Reuse Rules:
    1. Create a day-by-day itinerary of outfits. Each day should have a specific look tailored to the activities and weather of that day.
    2. SMART REUSE: You MUST intelligently reuse items across different days. Do not recommend the exact same complete outfit twice, but do reuse individual items (like the same pair of jeans, jacket, or sneakers) across multiple days to keep the packing list compact. The client should feel like they have a smart, cohesive capsule wardrobe.
    3. Match colors and layering details creatively. Provide styling tips for each day (e.g. French tucking, rolling sleeves, layering).
    4. Day-by-day activity matching: For each day, describe what the look is for (e.g. travel day, sightseeing, dinner, beach, active, etc.) matching the user's activities.

    Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
    {{
      "success": true,
      "destination": "{data.destination}",
      "days_count": {data.days},
      "itinerary": [
        {{
          "day_number": 1,
          "date": "YYYY-MM-DD or Day 1 details",
          "activity": "Activity for this day (e.g. Travel & Casual Dinner)",
          "weather": "Weather condition for this day (e.g. Mild and breezy)",
          "style_concept": "Style theme/vibe (e.g. Casual Chic, Edgy Streetwear)",
          "styling_tip": "Specific stylist instructions on tucking, rolling, layering, or accessories.",
          "outfit": {{
            "description": "Fashion rationale for this combination.",
            "items": [
              {{
                "id": 1,
                "category": "Tops",
                "subcategory": "Shirt",
                "color": "White",
                "image_path": "https://..."
              }}
            ]
          }}
        }}
      ],
      "missing_items": [
        "Heavy winter coat (since forecast is cold but no coats in wardrobe)"
      ],
      "packing_tip": "Roll light knits and use packing cubes to categorize items."
    }}
    """

    try:
        response_text = call_gemini(prompt)
        cleaned = clean_json_response(response_text)
        result = json.loads(cleaned)
        return result
    except Exception as e:
        return {"success": False, "message": str(e)}

@app.post("/regenerate-day-outfit")
def regenerate_day_outfit(data: RegenerateDayOutfitRequest, db: Session = Depends(get_db)):
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
    You are a creative, professional personal fashion stylist specializing in modern, high-end, Pinterest-style aesthetics.
    The user wants to replace/regenerate the outfit for Day {data.day_number} of their trip to {data.destination}.

    Day Details:
    - Date: {data.date}
    - Activity: {data.activity}
    - Weather: {data.weather}
    - Trip Type: {data.trip_type}

    Previously generated outfit item IDs for this day (DO NOT repeat this exact combination): {data.previous_outfit_item_ids}
    
    Currently Packed Items (used on other days of the trip):
    These items are already in the user's suitcase. To minimize packing, you should STRONGLY prioritize styling this day's look using items from this list if appropriate:
    {data.other_days_outfits}

    Here is the user's complete wardrobe (in JSON format):
    {clothes_json}

    Styling Rules:
    1. Select appropriate items from the wardrobe to complete a full outfit for this day (Tops + Bottoms OR a Single Dress, plus optional Outerwear/Shoes/Accessories).
    2. Smart Capsule Reuse: Prioritize items that are already packed (i.e. present in the currently packed items list) to avoid making the user pack new items. Only choose new wardrobe items if they are necessary for the specific weather/activities or if the packed items are completely unsuitable.
    3. Do not recommend the exact same combination of items as {data.previous_outfit_item_ids}.
    4. Give a creative style concept, styling tip, and explanation.

    Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
    {{
      "success": true,
      "style_concept": "Style theme/vibe (e.g. Edgy Casual)",
      "styling_tip": "Specific styling details (e.g. French tuck, roll sleeves)",
      "description": "Stylist rationale for the new outfit combination.",
      "outfit": {{
        "items": [
          {{
            "id": 1,
            "category": "Tops",
            "subcategory": "Shirt",
            "color": "White",
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
        items=serialized_items,
        tags=data.tags
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
            "items": x.items,
            "tags": x.tags if x.tags is not None else []
        })
    return {"success": True, "saved_outfits": result}

@app.post("/update-outfit-tags")
def update_outfit_tags(data: UpdateOutfitTagsRequest, db: Session = Depends(get_db)):
    outfit = db.query(SavedOutfit).filter(SavedOutfit.id == data.id).first()
    if not outfit:
        raise HTTPException(status_code=404, detail="Saved outfit not found")
    outfit.tags = data.tags
    db.commit()
    return {"success": True, "message": "Outfit tags updated successfully"}

@app.delete("/delete-saved-outfit/{outfit_id}")
def delete_saved_outfit(outfit_id: int, db: Session = Depends(get_db)):
    outfit = db.query(SavedOutfit).filter(SavedOutfit.id == outfit_id).first()
    if not outfit:
        raise HTTPException(status_code=404, detail="Saved outfit not found")
    db.delete(outfit)
    db.commit()
    return {"success": True, "message": "Saved outfit deleted successfully"}
