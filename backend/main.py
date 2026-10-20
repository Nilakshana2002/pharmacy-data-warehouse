"""
Pharmacy Data Warehouse System - FastAPI Application Entry Point
Module: backend/main.py
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
from backend.routers import analytics
from backend.database import check_db_connection

app = FastAPI(
    title="Pharmacy Data Warehouse OLAP API",
    description="Analytical query service for central_pharmacy_dwh star schema (Sales, Inventory Batches, Claims).",
    version="1.0.0"
)

# 1. Configure CORS to allow all origins for localhost development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Mount the analytics router under prefix '/api/analytics'
app.include_router(analytics.router)


# 3. Health check route at GET '/api/health'
@app.get("/api/health", tags=["health"])
def health_check():
    """System health check endpoint verifying database connectivity."""
    db_status = check_db_connection()
    return {
        "status": "HEALTHY" if db_status.get("connected") else "DEGRADED",
        "service": "pharmacy-dwh-backend",
        "timestamp": datetime.utcnow().isoformat(),
        "database": db_status
    }


# Root route
@app.get("/", tags=["root"])
def root():
    return {
        "service": "Pharmacy Data Warehouse OLAP API",
        "version": "1.0.0",
        "docs_url": "/docs",
        "health_check": "/api/health",
        "endpoints": [
            "/api/analytics/kpis",
            "/api/analytics/profitability",
            "/api/analytics/inventory-alerts",
            "/api/analytics/claims-summary"
        ]
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)
