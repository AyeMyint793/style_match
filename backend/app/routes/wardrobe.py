import sys
import traceback

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import ClothingItem, SavedOutfit
from ..schemas import ClothingSaveRequest, SaveOutfitRequest

router = APIRouter(tags=["Wardrobe Management"])

@router.post("/save-clothes")
def save_clothes(item: ClothingSaveRequest, db: Session = Depends(get_db)):
    try:
        # Defensive normalization: map common synonyms/variants to canonical categories
        cat = (item.category or '').strip()
        cat_lower = cat.lower()
        category_map = {
            't-shirt': 'Tops', 'tshirt': 'Tops', 'shirt': 'Tops', 'top': 'Tops', 'tops': 'Tops',
            'jeans': 'Bottoms', 'trousers': 'Bottoms', 'pants': 'Bottoms', 'bottom': 'Bottoms', 'bottoms': 'Bottoms',
            'dress': 'Dress', 'dresses': 'Dress',
            'shoe': 'Shoes', 'shoes': 'Shoes', 'sneakers': 'Shoes', 'boots': 'Shoes',
            'jacket': 'Outerwear', 'coat': 'Outerwear', 'outerwear': 'Outerwear',
            'bag': 'Accessories', 'handbag': 'Accessories', 'purse': 'Accessories', 'accessories': 'Accessories'
        }
        canonical_category = category_map.get(cat_lower, item.category)

        # Normalize season values minimally
        season_val = (item.season or '').strip()
        season_map = {'summer': 'Summer', 'winter': 'Winter', 'all season': 'All Season'}
        canonical_season = season_map.get(season_val.lower(), item.season)

        # Preserve color as provided; if empty or blank, keep as is (empty string)
        color_val = item.color if item.color is not None else ''

        clothing = ClothingItem(
            email=item.email,
            image_path=item.image_path,
            category=canonical_category,
            subcategory=item.subcategory,
            occasion=item.occasion,
            season=canonical_season,
            color=color_val,
            stylist_note=item.stylist_note
        )
        db.add(clothing)
        db.commit()
        db.refresh(clothing)
        return {"success": True, "message": "Clothing item saved successfully", "id": clothing.id}
    except Exception:
        db.rollback()
        print("save_clothes failed", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        raise

@router.get("/get-clothes")
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
            "color": x.color or "",
            "stylist_note": x.stylist_note or ""
        })
    return {"success": True, "clothes": clothes_list}

@router.delete("/delete-clothes/{item_id}")
def delete_clothes(item_id: int, db: Session = Depends(get_db)):
    item = db.query(ClothingItem).filter(ClothingItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Clothing item not found")
    db.delete(item)
    db.commit()
    return {"success": True, "message": "Clothing item deleted successfully"}

@router.post("/save-outfit")
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

@router.get("/get-saved-outfits")
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

@router.delete("/delete-saved-outfit/{outfit_id}")
def delete_saved_outfit(outfit_id: int, db: Session = Depends(get_db)):
    outfit = db.query(SavedOutfit).filter(SavedOutfit.id == outfit_id).first()
    if not outfit:
        raise HTTPException(status_code=404, detail="Saved outfit not found")
    db.delete(outfit)
    db.commit()
    return {"success": True, "message": "Saved outfit deleted successfully"}
