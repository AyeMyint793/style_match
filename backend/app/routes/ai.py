from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List
import json
from ..database import get_db
from ..models import User, UserPreference, ClothingItem
from ..schemas import GenerateOutfitRequest, CompleteOutfitRequest, TripPackingRequest
from ..services.ai_service import AIService
from ..services.insight_service import InsightService

router = APIRouter(tags=["AI Styling Engine"])

@router.post("/generate-outfit")
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

    items_json = json.dumps([{
        "id": x.id,
        "category": x.category,
        "subcategory": x.subcategory,
        "color": x.color,
        "season": x.season,
        "occasion": x.occasion,
        "image_path": x.image_path
    } for x in items], indent=2)

    result = AIService.generate_outfit(
        user.height, user.size, pref_fit, pref_style,
        data.occasion, data.season, data.weather,
        data.shown_item_ids, items_json
    )
    return result

@router.post("/complete-outfit")
def complete_outfit(data: CompleteOutfitRequest, db: Session = Depends(get_db)):
    items = db.query(ClothingItem).filter(ClothingItem.email == data.email).all()
    if not items:
        return {"success": False, "message": "Wardrobe is empty"}

    items_json = json.dumps([{
        "id": x.id,
        "category": x.category,
        "subcategory": x.subcategory,
        "color": x.color,
        "season": x.season,
        "occasion": x.occasion,
        "image_path": x.image_path
    } for x in items], indent=2)

    result = AIService.complete_outfit(data.selected_item, items_json)
    return result

@router.get("/analyze-wardrobe")
def analyze_wardrobe(email: str = Query(...), db: Session = Depends(get_db)):
    items = db.query(ClothingItem).filter(ClothingItem.email == email).all()
    if not items:
        return {"success": True, "stats": {"total_items": 0}, "insights": [{"suggestion": "Add tops and bottoms to your wardrobe to get started!"}], "gaps": [{"suggestion": "Add tops and bottoms to your wardrobe to get started!"}]}

    # Use deterministic, rule-based insight computation based on real DB records
    stats = InsightService.compute_stats(items)
    insights = InsightService.generate_insights_from_stats(stats)

    return {"success": True, "stats": stats, "insights": insights, "gaps": insights}

@router.post("/trip-packing")
def trip_packing(data: TripPackingRequest, db: Session = Depends(get_db)):
    items = db.query(ClothingItem).filter(ClothingItem.email == data.email).all()
    if not items:
        return {"success": False, "message": "Wardrobe is empty. Add clothes first."}

    items_json = json.dumps([{
        "id": x.id,
        "category": x.category,
        "subcategory": x.subcategory,
        "color": x.color,
        "season": x.season,
        "occasion": x.occasion,
        "image_path": x.image_path
    } for x in items], indent=2)

    result = AIService.trip_packing(
        data.destination, data.days, data.trip_type,
        data.activities, data.weather, items_json
    )
    return result
