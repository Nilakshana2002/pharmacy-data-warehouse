"""
Pharmacy Data Warehouse System - SQLAlchemy Connection Pool
Module: backend/database.py
Target Database: central_pharmacy_dwh
"""

import os
import logging
from typing import List, Dict, Any, Optional
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import QueuePool

# Load environment variables
load_dotenv()

logger = logging.getLogger("pharmacy_dwh.database")
logging.basicConfig(level=logging.INFO)

# Database connection parameters
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "1234")
DB_NAME = os.getenv("DB_NAME", "central_pharmacy_dwh")

# SQLAlchemy connection string using mysql-connector-python dialect
DATABASE_URL = f"mysql+mysqlconnector://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# SQLAlchemy Engine with production connection pool
engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=10,
    max_overflow=20,
    pool_recycle=3600,
    pool_pre_ping=True,
    connect_args={
        "connection_timeout": 5
    }
)

# Session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    """FastAPI dependency for obtaining a database session."""
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def check_db_connection() -> Dict[str, Any]:
    """Verify if the MySQL connection pool is healthy and reachable."""
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT DATABASE() AS current_db, VERSION() AS mysql_version")).mappings().first()
            return {
                "connected": True,
                "database": result["current_db"] if result else DB_NAME,
                "version": result["mysql_version"] if result else "unknown"
            }
    except Exception as ex:
        logger.error(f"Database health check failed: {ex}")
        return {
            "connected": False,
            "error": str(ex),
            "database": DB_NAME
        }


def execute_query(sql_query: str, params: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    """
    Execute a parameterized SQL analytical query using the connection pool.
    Returns results as a list of dictionaries.
    """
    with engine.connect() as conn:
        result = conn.execute(text(sql_query), params or {})
        mappings = result.mappings().all()
        return [dict(row) for row in mappings]


def execute_procedure(procedure_name: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Execute a stored procedure in MySQL."""
    with engine.connect() as conn:
        conn.execute(text(f"CALL {procedure_name}()"))
        conn.commit()
        return {"status": "SUCCESS", "procedure": procedure_name}
