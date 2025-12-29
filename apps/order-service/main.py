# Order Service - FastAPI Microservice
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from enum import Enum
import uuid
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Order Service",
    description="Order management microservice",
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

# Enums
class OrderStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"

# Models
class OrderItem(BaseModel):
    product_id: str
    quantity: int
    price: float

class OrderCreate(BaseModel):
    user_id: str
    items: list[OrderItem]

class OrderUpdate(BaseModel):
    status: Optional[OrderStatus] = None

class Order(BaseModel):
    id: str
    user_id: str
    items: list[OrderItem]
    total: float
    status: OrderStatus
    created_at: datetime
    updated_at: datetime

# In-memory database
orders_db: dict[str, dict] = {}

# Health check endpoints
@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "healthy", "service": "order-service"}

@app.get("/ready", tags=["Health"])
async def readiness_check():
    return {"status": "ready", "service": "order-service"}

@app.get("/metrics", tags=["Monitoring"])
async def metrics():
    return {
        "total_orders": len(orders_db),
        "service": "order-service"
    }

# Order CRUD endpoints
@app.post("/api/v1/orders", response_model=Order, status_code=status.HTTP_201_CREATED, tags=["Orders"])
async def create_order(order: OrderCreate):
    """Create a new order"""
    order_id = str(uuid.uuid4())
    now = datetime.utcnow()
    
    total = sum(item.price * item.quantity for item in order.items)
    
    order_data = {
        "id": order_id,
        "user_id": order.user_id,
        "items": [item.model_dump() for item in order.items],
        "total": total,
        "status": OrderStatus.PENDING,
        "created_at": now,
        "updated_at": now
    }
    
    orders_db[order_id] = order_data
    logger.info(f"Created order: {order_id}")
    return order_data

@app.get("/api/v1/orders", tags=["Orders"])
async def list_orders(user_id: Optional[str] = None):
    """List all orders, optionally filtered by user_id"""
    orders = list(orders_db.values())
    if user_id:
        orders = [o for o in orders if o["user_id"] == user_id]
    return {"orders": orders, "total": len(orders)}

@app.get("/api/v1/orders/{order_id}", response_model=Order, tags=["Orders"])
async def get_order(order_id: str):
    """Get a specific order by ID"""
    if order_id not in orders_db:
        raise HTTPException(status_code=404, detail="Order not found")
    return orders_db[order_id]

@app.put("/api/v1/orders/{order_id}", response_model=Order, tags=["Orders"])
async def update_order(order_id: str, order: OrderUpdate):
    """Update order status"""
    if order_id not in orders_db:
        raise HTTPException(status_code=404, detail="Order not found")
    
    existing_order = orders_db[order_id]
    
    if order.status is not None:
        existing_order["status"] = order.status
    
    existing_order["updated_at"] = datetime.utcnow()
    logger.info(f"Updated order: {order_id}")
    return existing_order

@app.delete("/api/v1/orders/{order_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Orders"])
async def delete_order(order_id: str):
    """Delete an order"""
    if order_id not in orders_db:
        raise HTTPException(status_code=404, detail="Order not found")
    
    del orders_db[order_id]
    logger.info(f"Deleted order: {order_id}")
    return None

@app.get("/", tags=["Root"])
async def root():
    return {
        "service": "order-service",
        "version": "1.0.0",
        "docs": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8001))
    uvicorn.run(app, host="0.0.0.0", port=port)
