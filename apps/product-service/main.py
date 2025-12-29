# Product Service - FastAPI Microservice
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import uuid
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Product Service",
    description="Product catalog microservice",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Models
class ProductCreate(BaseModel):
    name: str
    description: str
    price: float
    stock: int
    category: str

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None
    category: Optional[str] = None

class Product(BaseModel):
    id: str
    name: str
    description: str
    price: float
    stock: int
    category: str
    created_at: datetime
    updated_at: datetime

# In-memory database with sample data
products_db: dict[str, dict] = {
    "prod-001": {
        "id": "prod-001",
        "name": "Laptop",
        "description": "High-performance laptop",
        "price": 999.99,
        "stock": 50,
        "category": "Electronics",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    },
    "prod-002": {
        "id": "prod-002",
        "name": "Wireless Mouse",
        "description": "Ergonomic wireless mouse",
        "price": 29.99,
        "stock": 200,
        "category": "Electronics",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
}

# Health endpoints
@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "healthy", "service": "product-service"}

@app.get("/ready", tags=["Health"])
async def readiness_check():
    return {"status": "ready", "service": "product-service"}

@app.get("/metrics", tags=["Monitoring"])
async def metrics():
    return {
        "total_products": len(products_db),
        "service": "product-service"
    }

# Product CRUD endpoints
@app.post("/api/v1/products", response_model=Product, status_code=status.HTTP_201_CREATED, tags=["Products"])
async def create_product(product: ProductCreate):
    """Create a new product"""
    product_id = str(uuid.uuid4())
    now = datetime.utcnow()
    
    product_data = {
        "id": product_id,
        "name": product.name,
        "description": product.description,
        "price": product.price,
        "stock": product.stock,
        "category": product.category,
        "created_at": now,
        "updated_at": now
    }
    
    products_db[product_id] = product_data
    logger.info(f"Created product: {product_id}")
    return product_data

@app.get("/api/v1/products", tags=["Products"])
async def list_products(category: Optional[str] = None):
    """List all products, optionally filtered by category"""
    products = list(products_db.values())
    if category:
        products = [p for p in products if p["category"].lower() == category.lower()]
    return {"products": products, "total": len(products)}

@app.get("/api/v1/products/{product_id}", response_model=Product, tags=["Products"])
async def get_product(product_id: str):
    """Get a specific product by ID"""
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    return products_db[product_id]

@app.put("/api/v1/products/{product_id}", response_model=Product, tags=["Products"])
async def update_product(product_id: str, product: ProductUpdate):
    """Update a product"""
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    
    existing = products_db[product_id]
    
    for field, value in product.model_dump(exclude_unset=True).items():
        if value is not None:
            existing[field] = value
    
    existing["updated_at"] = datetime.utcnow()
    logger.info(f"Updated product: {product_id}")
    return existing

@app.delete("/api/v1/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Products"])
async def delete_product(product_id: str):
    """Delete a product"""
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    
    del products_db[product_id]
    logger.info(f"Deleted product: {product_id}")
    return None

@app.get("/", tags=["Root"])
async def root():
    return {
        "service": "product-service",
        "version": "1.0.0",
        "docs": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8002))
    uvicorn.run(app, host="0.0.0.0", port=port)
