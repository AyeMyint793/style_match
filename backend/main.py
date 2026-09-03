import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.routes import auth, profile, wardrobe, ai

# Ensure all database tables are created (using existing users.db)
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

        # Check clothing_items table
        result_clothing = conn.execute(text("PRAGMA table_info(clothing_items)"))
        columns_clothing = [row[1] for row in result_clothing.fetchall()]
        if "stylist_note" not in columns_clothing:
            conn.execute(text("ALTER TABLE clothing_items ADD COLUMN stylist_note TEXT"))
            conn.commit()
            print("Successfully added 'stylist_note' column to 'clothing_items' table.")
except Exception as e:
    print(f"Error altering database tables in main.py: {e}")

app = FastAPI(
    title="Style Match - Modular API",
    description="Refactored backend for the Style Match fashion application.",
    version="2.0.0"
)

# CORS CONFIGURATION
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# REGISTER MODULAR ROUTERS
app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(wardrobe.router)
app.include_router(ai.router)

@app.get("/")
def root():
    """Health check endpoint to verify backend status."""
    return {
        "status": "online",
        "version": "2.0.0",
        "modules": ["auth", "profile", "wardrobe", "ai"],
        "message": "Style Match Modular Backend is running."
    }
