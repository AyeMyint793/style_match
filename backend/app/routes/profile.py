import cloudinary
import cloudinary.uploader
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User, UserPreference
from ..schemas import ProfileRequest, PreferenceRequest

router = APIRouter(tags=["Profile Management"])

@router.post("/upload-avatar")
async def upload_avatar(file: UploadFile = File(...)):
    try:
        raw_bytes = await file.read()
        upload_result = cloudinary.uploader.upload(
            raw_bytes,
            folder="style_match_avatars"
        )
        secure_url = upload_result.get("secure_url")
        if not secure_url:
            raise HTTPException(status_code=500, detail="Avatar upload failed")
        return {"success": True, "avatar_url": secure_url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/save-profile")
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

@router.get("/get-profile")
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

@router.post("/save-preferences")
def save_preferences(data: PreferenceRequest, db: Session = Depends(get_db)):
    pref = db.query(UserPreference).filter(UserPreference.email == data.email).first()
    if not pref:
        pref = UserPreference(email=data.email)
        db.add(pref)
    pref.fit = data.fit
    pref.style = data.style
    db.commit()
    return {"success": True, "message": "Preferences saved successfully"}

@router.get("/get-preferences")
def get_preferences(email: str = Query(...), db: Session = Depends(get_db)):
    pref = db.query(UserPreference).filter(UserPreference.email == email).first()
    if not pref:
        return {"success": True, "fit": "Regular", "style": "Casual"}
    return {"success": True, "fit": pref.fit, "style": pref.style}
