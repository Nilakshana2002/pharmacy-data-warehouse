"""
Pharmacy Data Warehouse System - FastAPI Application Entry Point
File: backend/main.py
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.routers import analytics
from backend.database import is_mysql_connected

app = FastAPI(
    title="Pharmacy Data Warehouse System API",
    description="Enterprise ELT & Star Schema Analytical API for Pharmacy Core, POS, Inventory, and Insurance Claims.",
    version="1.0.0"
)

# Enable CORS for development frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(analytics.router)


@app.get("/")
def root():
    return {
        "system": "Pharmacy Data Warehouse & Analytics Platform",
        "version": "1.0.0",
        "status": "ONLINE",
        "database_connected": is_mysql_connected(),
        "docs_url": "/docs"
    }


@app.get("/health")
def health_check():
    return {
        "status": "HEALTHY",
        "database": "CONNECTED" if is_mysql_connected() else "DISCONNECTED",
        "dwh_target": "central_pharmacy_dwh"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)
