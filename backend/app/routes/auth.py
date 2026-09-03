import hashlib
import secrets
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User
from ..schemas import RegisterRequest, LoginRequest, ForgotPasswordRequest, ResetPasswordRequest

router = APIRouter(tags=["Authentication"])

def hash_password(password: str) -> str:
    """Create a secure PBKDF2-HMAC-SHA256 password hash (100,000 iterations)."""
    salt = secrets.token_bytes(16)
    key = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
    return f"pbkdf2_sha256$100000${salt.hex()}${key.hex()}"

def verify_password(plain_password: str, stored_password: str) -> bool:
    """Verify password with support for PBKDF2-HMAC-SHA256, salted SHA-256, and legacy plaintext."""
    if not stored_password:
        return False
    if stored_password.startswith("pbkdf2_sha256$"):
        parts = stored_password.split("$")
        if len(parts) == 4:
            try:
                iterations = int(parts[1])
                salt = bytes.fromhex(parts[2])
                stored_key = parts[3]
                computed_key = hashlib.pbkdf2_hmac('sha256', plain_password.encode('utf-8'), salt, iterations).hex()
                return secrets.compare_digest(computed_key, stored_key)
            except Exception:
                return False
    elif stored_password.startswith("sha256$"):
        parts = stored_password.split("$")
        if len(parts) == 3:
            salt, stored_hash = parts[1], parts[2]
            computed_hash = hashlib.sha256((salt + plain_password).encode("utf-8")).hexdigest()
            return secrets.compare_digest(computed_hash, stored_hash)
    # Fallback for existing legacy passwords
    return plain_password == stored_password

@router.post("/register")
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == data.email).first()
    if existing_user:
        return {"success": False, "message": "Email already registered"}

    user = User(email=data.email, password=hash_password(data.password))
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"success": True, "message": "User registered successfully"}

@router.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        return {"success": False, "message": "User not found"}
    
    if not verify_password(data.password, user.password):
        return {"success": False, "message": "Incorrect password"}
    
    # Auto-upgrade any older hash or plaintext password to PBKDF2-HMAC-SHA256 on login
    if not user.password.startswith("pbkdf2_sha256$"):
        user.password = hash_password(data.password)
        db.commit()

    return {"success": True, "message": "Login successful"}

@router.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        return {"success": False, "message": "Email not found"}
    return {"success": True, "message": "Account verified. Please set your new password."}

@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        return {"success": False, "message": "User not found"}

    user.password = hash_password(data.new_password)
    db.commit()
    return {"success": True, "message": "Password reset successfully"}

