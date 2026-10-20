"""
Pharmacy Data Warehouse System - Database Connection & Query Engine
Module: backend/database.py
"""

import os
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env if present
load_dotenv()

logger = logging.getLogger("pharmacy_dwh.database")
logging.basicConfig(level=logging.INFO)

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "central_pharmacy_dwh")

# Global connection flag
_mysql_available = False
_connection_pool = None

try:
    import mysql.connector
    from mysql.connector import pooling

    try:
        _connection_pool = pooling.MySQLConnectionPool(
            pool_name="dwh_pool",
            pool_size=5,
            pool_reset_session=True,
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            connect_timeout=3
        )
        # Test connection
        conn = _connection_pool.get_connection()
        conn.close()
        _mysql_available = True
        logger.info(f"Successfully connected to MySQL Database '{DB_NAME}' at {DB_HOST}:{DB_PORT}")
    except Exception as ex:
        logger.warning(f"Live MySQL connection could not be established ({ex}). Operating in intelligent DWH demo mode.")
        _mysql_available = False
except ImportError:
    logger.warning("mysql-connector-python is not installed. Operating in fallback data mode.")
    _mysql_available = False


def is_mysql_connected() -> bool:
    """Check if live MySQL database is accessible."""
    return _mysql_available


def execute_query(query: str, params: Optional[tuple] = None) -> List[Dict[str, Any]]:
    """
    Execute a SELECT query against central_pharmacy_dwh.
    Returns list of row dictionaries.
    """
    if not _mysql_available or _connection_pool is None:
        raise ConnectionError("MySQL connection not available")

    conn = None
    try:
        conn = _connection_pool.get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(query, params or ())
        results = cursor.fetchall()
        cursor.close()
        return results
    finally:
        if conn and conn.is_connected():
            conn.close()


def execute_stored_procedure(proc_name: str, args: tuple = ()) -> Dict[str, Any]:
    """Execute a stored procedure such as sp_Run_Pharmacy_ELT."""
    if not _mysql_available or _connection_pool is None:
        raise ConnectionError("MySQL connection not available")

    conn = None
    try:
        conn = _connection_pool.get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.callproc(proc_name, args)
        conn.commit()
        cursor.close()
        return {"status": "SUCCESS", "message": f"Procedure {proc_name} executed successfully"}
    finally:
        if conn and conn.is_connected():
            conn.close()
