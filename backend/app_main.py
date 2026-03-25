from fastapi import FastAPI, Depends
from pydantic import BaseModel, EmailStr
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import sessionmaker, declarative_base, Session

app = FastAPI()

# DATABASE SETUP
DATABASE_URL = "sqlite:///./users.db"

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(bind=engine)

Base = declarative_base()


# DATABASE TABLE
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=True)
    email = Column(String, unique=True)
    password = Column(String)
    age = Column(Integer, nullable=True)
    gender = Column(String, nullable=True)
    style = Column(String, nullable=True)

    # ✅ NEW FIELDS
    height = Column(String, nullable=True)
    size = Column(String, nullable=True)


# CREATE DATABASE
Base.metadata.create_all(bind=engine)


# REQUEST MODELS
class RegisterRequest(BaseModel):
    email: EmailStr
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class ProfileRequest(BaseModel):
    email: EmailStr
    name: str
    age: int
    gender: str
    style: str


class Profile(BaseModel):
    email: EmailStr
    name: str
    height: str
    size: str


# DATABASE SESSION
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.get("/")
def home():
    return {"message": "Style Match Backend Running with Database"}


# REGISTER USER
@app.post("/register")
def register(data: RegisterRequest, db: Session = Depends(get_db)):

    existing_user = db.query(User).filter(User.email == data.email).first()
    if existing_user:
        return {"error": "Email already registered"}

    user = User(email=data.email, password=data.password)

    db.add(user)
    db.commit()
    db.refresh(user)

    return {"message": "User registered successfully"}


# LOGIN USER
@app.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):

    user = db.query(User).filter(User.email == data.email).first()

    if not user:
        return {"error": "User not found"}

    if user.password != data.password:
        return {"error": "Incorrect password"}

    return {"message": "Login successful"}


# PROFILE SETUP (old one - optional)
@app.post("/profile")
def setup_profile(data: ProfileRequest, db: Session = Depends(get_db)):

    user = db.query(User).filter(User.email == data.email).first()

    if not user:
        return {"error": "User not found"}

    user.name = data.name
    user.age = data.age
    user.gender = data.gender
    user.style = data.style

    db.commit()
    db.refresh(user)

    return {"message": "Profile saved successfully"}


# ✅ SAVE PROFILE (for your Flutter screen)
@app.post("/save-profile")
def save_profile(profile: Profile, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == profile.email).first()

    if not user:
        return {"error": "User not found"}

    user.name = profile.name
    user.height = profile.height
    user.size = profile.size

    db.commit()

    return {"message": "Profile saved successfully"}


# ✅ GET PROFILE (for auto-fill)
@app.get("/get-profile/{email}")
def get_profile(email: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == email).first()

    if not user:
        return {"error": "User not found"}

    return {
        "name": user.name,
        "height": user.height,
        "size": user.size
    }