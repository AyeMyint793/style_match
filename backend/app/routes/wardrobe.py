import sys
import os
import io
import traceback
import concurrent.futures
import cloudinary
import cloudinary.uploader
from PIL import Image

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import ClothingItem, SavedOutfit
from ..schemas import ClothingSaveRequest, ClothingUpdateRequest, BatchClothingSaveRequest, SaveOutfitRequest, UpdateOutfitTagsRequest
from ..services.image_service import ImageService
from ..services.ai_service import AIService

# Configure Cloudinary
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)

router = APIRouter(tags=["Wardrobe Management"])


@router.post("/process-image")
async def process_image(file: UploadFile = File(...)):
    try:
        raw_bytes = await file.read()
        mime = file.content_type or "image/jpeg"
        
        # 1. First detect garments with bounding boxes to avoid mangling real room backgrounds
        detection = AIService.detect_multiple_clothes(raw_bytes, mime_type=mime)
        
        if detection.get("success") and detection.get("items"):
            item = detection["items"][0]
            box = item.get("box_2d", [0, 0, 1000, 1000])
            master_img = ImageService.load_image_from_bytes(raw_bytes)
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
                return {
                    "success": True,
                    "image_url": secure_url,
                    "tags": tags
                }

        # Fallback for true single-garment photos. Detect from the original image first,
        # then process with the detected category so the cleanup does not invent shapes.
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

@router.post("/process-multi-image")
async def process_multi_image(file: UploadFile = File(...)):
    try:
        raw_bytes = await file.read()
        mime = file.content_type or "image/jpeg"
        detection = AIService.detect_multiple_clothes(raw_bytes, mime_type=mime)
        
        if not detection.get("success") or not detection.get("items"):
            # Try single-item fallback
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

        # Concurrently process crops and uploads for maximum speed
        max_workers = min(max(len(detected_items), 1), 6)
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
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

@router.post("/batch-save-clothes")
def batch_save_clothes(data: BatchClothingSaveRequest, db: Session = Depends(get_db)):
    try:
        saved_ids = []
        category_map = {
            't-shirt': 'Tops', 'tshirt': 'Tops', 'shirt': 'Tops', 'top': 'Tops', 'tops': 'Tops',
            'jeans': 'Bottoms', 'trousers': 'Bottoms', 'pants': 'Bottoms', 'bottom': 'Bottoms', 'bottoms': 'Bottoms',
            'dress': 'Dress', 'dresses': 'Dress',
            'shoe': 'Shoes', 'shoes': 'Shoes', 'sneakers': 'Shoes', 'boots': 'Shoes',
            'jacket': 'Outerwear', 'coat': 'Outerwear', 'outerwear': 'Outerwear',
            'bag': 'Accessories', 'handbag': 'Accessories', 'purse': 'Accessories', 'accessories': 'Accessories'
        }
        season_map = {'summer': 'Summer', 'winter': 'Winter', 'all season': 'All Season'}

        for item in data.items:
            cat = (item.category or '').strip()
            canonical_category = category_map.get(cat.lower(), item.category)
            season_val = (item.season or '').strip()
            canonical_season = season_map.get(season_val.lower(), item.season)

            clothing = ClothingItem(
                email=data.email,
                image_path=item.image_path,
                category=canonical_category,
                subcategory=item.subcategory,
                occasion=item.occasion,
                season=canonical_season,
                color=item.color or '',
                stylist_note=item.stylist_note or ''
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

@router.post("/update-clothes")
def update_clothes(data: ClothingUpdateRequest, db: Session = Depends(get_db)):
    try:
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
    except Exception as e:
        db.rollback()
        print("update_clothes failed", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(e))

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
        items=serialized_items,
        tags=data.tags
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
            "items": x.items,
            "tags": x.tags if x.tags is not None else []
        })
    return {"success": True, "saved_outfits": result}

@router.post("/update-outfit-tags")
def update_outfit_tags(data: UpdateOutfitTagsRequest, db: Session = Depends(get_db)):
    outfit = db.query(SavedOutfit).filter(SavedOutfit.id == data.id).first()
    if not outfit:
        raise HTTPException(status_code=404, detail="Saved outfit not found")
    outfit.tags = data.tags
    db.commit()
    return {"success": True, "message": "Outfit tags updated successfully"}

@router.delete("/delete-saved-outfit/{outfit_id}")
def delete_saved_outfit(outfit_id: int, db: Session = Depends(get_db)):
    outfit = db.query(SavedOutfit).filter(SavedOutfit.id == outfit_id).first()
    if not outfit:
        raise HTTPException(status_code=404, detail="Saved outfit not found")
    db.delete(outfit)
    db.commit()
    return {"success": True, "message": "Saved outfit deleted successfully"}
