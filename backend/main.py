import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.routes import auth, profile, wardrobe, ai

# Ensure all database tables are created (using existing users.db)
Base.metadata.create_all(bind=engine)

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
