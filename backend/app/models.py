from sqlalchemy import Column, Integer, String, JSON, Boolean
from .database import Base

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
    stylist_note = Column(String, nullable=True) # New Field for intelligence persistence

class SavedOutfit(Base):
    __tablename__ = "saved_outfits"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, index=True)
    occasion = Column(String)
    season = Column(String)
    description = Column(String)
    items = Column(JSON)  # Stores detailed serialized items list
