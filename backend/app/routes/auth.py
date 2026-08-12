from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User
from ..schemas import RegisterRequest, LoginRequest, ForgotPasswordRequest, ResetPasswordRequest

router = APIRouter(tags=["Authentication"])

@router.post("/register")
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == data.email).first()
    if existing_user:
        return {"success": False, "message": "Email already registered"}

    user = User(email=data.email, password=data.password)
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"success": True, "message": "User registered successfully"}

@router.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        return {"success": False, "message": "User not found"}
    if user.password != data.password:
        return {"success": False, "message": "Incorrect password"}
    return {"success": True, "message": "Login successful"}

@router.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        return {"success": False, "message": "Email not found"}
    # Modular approach: In production, send a reset email here.
    return {"success": True, "message": "Account verified. Please set your new password."}

@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        return {"success": False, "message": "User not found"}

    user.password = data.new_password
    db.commit()
    return {"success": True, "message": "Password reset successfully"}
