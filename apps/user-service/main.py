# User Service - FastAPI Microservice
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime
import uuid
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="User Service",
    description="User management microservice",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Models
class UserCreate(BaseModel):
    name: str
    email: EmailStr

class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None

class User(BaseModel):
    id: str
    name: str
    email: str
    created_at: datetime
    updated_at: datetime

# In-memory database (replace with real DB in production)
users_db: dict[str, dict] = {}

# Health check endpoints
@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint for Kubernetes probes"""
    return {"status": "healthy", "service": "user-service"}

@app.get("/ready", tags=["Health"])
async def readiness_check():
    """Readiness check endpoint for Kubernetes probes"""
    return {"status": "ready", "service": "user-service"}

# Metrics endpoint for Prometheus
@app.get("/metrics", tags=["Monitoring"])
async def metrics():
    """Basic metrics endpoint"""
    return {
        "total_users": len(users_db),
        "service": "user-service"
    }

# User CRUD endpoints
@app.post("/api/v1/users", response_model=User, status_code=status.HTTP_201_CREATED, tags=["Users"])
async def create_user(user: UserCreate):
    """Create a new user"""
    user_id = str(uuid.uuid4())
    now = datetime.utcnow()
    
    user_data = {
        "id": user_id,
        "name": user.name,
        "email": user.email,
        "created_at": now,
        "updated_at": now
    }
    
    users_db[user_id] = user_data
    logger.info(f"Created user: {user_id}")
    return user_data

@app.get("/api/v1/users", tags=["Users"])
async def list_users():
    """List all users"""
    return {"users": list(users_db.values()), "total": len(users_db)}

@app.get("/api/v1/users/{user_id}", response_model=User, tags=["Users"])
async def get_user(user_id: str):
    """Get a specific user by ID"""
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    return users_db[user_id]

@app.put("/api/v1/users/{user_id}", response_model=User, tags=["Users"])
async def update_user(user_id: str, user: UserUpdate):
    """Update a user"""
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    
    existing_user = users_db[user_id]
    
    if user.name is not None:
        existing_user["name"] = user.name
    if user.email is not None:
        existing_user["email"] = user.email
    
    existing_user["updated_at"] = datetime.utcnow()
    logger.info(f"Updated user: {user_id}")
    return existing_user

@app.delete("/api/v1/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Users"])
async def delete_user(user_id: str):
    """Delete a user"""
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    
    del users_db[user_id]
    logger.info(f"Deleted user: {user_id}")
    return None

# Root endpoint
@app.get("/", tags=["Root"])
async def root():
    """Root endpoint"""
    return {
        "service": "user-service",
        "version": "1.0.0",
        "docs": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
