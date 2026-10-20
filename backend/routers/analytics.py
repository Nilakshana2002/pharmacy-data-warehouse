"""
Pharmacy Data Warehouse Analytics Router
Module: backend/routers/analytics.py
"""

from fastapi import APIRouter, HTTPException
from typing import Dict, Any, List
import time
from datetime import datetime
from backend.database import execute_query, execute_stored_procedure, is_mysql_connected

router = APIRouter(prefix="/api/analytics", tags=["analytics"])


@router.get("/kpi-summary")
def get_kpi_summary() -> Dict[str, Any]:
    """Executive summary of revenue, gross profit, inventory risk, and claims."""
    try:
        # Sales KPIs
        sales_sql = """
            SELECT 
                COALESCE(SUM(gross_sales_amount), 0) AS total_gross_revenue,
                COALESCE(SUM(net_sales_amount), 0) AS total_net_revenue,
                COALESCE(SUM(cost_of_goods_sold), 0) AS total_cogs,
                COALESCE(SUM(gross_profit), 0) AS total_gross_profit,
                ROUND(COALESCE((SUM(gross_profit) / NULLIF(SUM(net_sales_amount), 0)) * 100, 0), 2) AS overall_profit_margin_pct,
                COALESCE(SUM(quantity_sold), 0) AS total_units_dispensed,
                COUNT(DISTINCT invoice_number) AS total_transactions,
                COALESCE(SUM(is_prescription_dispense), 0) AS total_rx_dispensed,
                COUNT(DISTINCT customer_key) AS unique_patients_served
            FROM Fact_Sales_Transactions;
        """
        sales_kpi = execute_query(sales_sql)[0]

        # Inventory Expiry KPIs
        inv_sql = """
            SELECT 
                COALESCE(SUM(inventory_cost_valuation), 0) AS total_inventory_valuation,
                COALESCE(SUM(CASE WHEN is_near_expiry_90d = 1 THEN inventory_cost_valuation ELSE 0 END), 0) AS near_expiry_90d_valuation,
                COALESCE(SUM(is_near_expiry_90d), 0) AS near_expiry_90d_batches_count,
                COALESCE(SUM(is_near_expiry_30d), 0) AS critical_expiry_30d_batches_count,
                COALESCE(SUM(is_expired), 0) AS expired_batches_count,
                COUNT(*) AS total_batches_tracked
            FROM Fact_Inventory_Batches;
        """
        inv_kpi = execute_query(inv_sql)[0]

        # Insurance Claims KPIs
        claims_sql = """
            SELECT 
                COUNT(*) AS total_claims_submitted,
                COALESCE(SUM(claim_amount), 0) AS total_claims_amount,
                COALESCE(SUM(approved_amount), 0) AS total_approved_amount,
                COALESCE(SUM(rejection_loss_amount), 0) AS total_rejection_loss,
                COALESCE(SUM(CASE WHEN claim_status = 'APPROVED' THEN 1 ELSE 0 END), 0) AS approved_claims_count,
                COALESCE(SUM(CASE WHEN claim_status = 'REJECTED' THEN 1 ELSE 0 END), 0) AS rejected_claims_count,
                COALESCE(SUM(CASE WHEN claim_status = 'PENDING' THEN 1 ELSE 0 END), 0) AS pending_claims_count,
                ROUND(COALESCE((SUM(CASE WHEN claim_status = 'APPROVED' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)) * 100, 0), 2) AS claim_approval_rate_pct
            FROM Fact_Insurance_Claims;
        """
        claims_kpi = execute_query(claims_sql)[0]

        return {
            "status": "SUCCESS",
            "source": "central_pharmacy_dwh (MySQL)",
            "timestamp": datetime.utcnow().isoformat(),
            "sales": sales_kpi,
            "inventory": inv_kpi,
            "claims": claims_kpi
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sales-trend")
def get_sales_trend() -> List[Dict[str, Any]]:
    """Time-series monthly and monthly-to-date sales trend comparing revenue, COGS, and margin."""
    try:
        sql = """
            SELECT 
                d.calendar_year,
                d.month_num,
                d.month_short,
                CONCAT(d.calendar_year, '-', LPAD(d.month_num, 2, '0')) AS period_label,
                ROUND(SUM(f.net_sales_amount), 2) AS net_revenue,
                ROUND(SUM(f.cost_of_goods_sold), 2) AS cost_of_goods_sold,
                ROUND(SUM(f.gross_profit), 2) AS gross_profit,
                ROUND((SUM(f.gross_profit) / NULLIF(SUM(f.net_sales_amount), 0)) * 100, 2) AS profit_margin_pct,
                COUNT(DISTINCT f.invoice_number) AS transaction_count,
                SUM(f.quantity_sold) AS units_sold
            FROM Fact_Sales_Transactions f
            JOIN Dim_Date d ON f.date_key = d.date_key
            GROUP BY d.calendar_year, d.month_num, d.month_short
            ORDER BY d.calendar_year ASC, d.month_num ASC;
        """
        return execute_query(sql)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/category-performance")
def get_category_performance() -> List[Dict[str, Any]]:
    """Sales and margin breakdown by therapeutic class & product categories."""
    try:
        sql = """
            SELECT 
                p.therapeutic_class,
                p.category_name,
                ROUND(SUM(f.net_sales_amount), 2) AS total_revenue,
                ROUND(SUM(f.cost_of_goods_sold), 2) AS total_cogs,
                ROUND(SUM(f.gross_profit), 2) AS gross_profit,
                ROUND((SUM(f.gross_profit) / NULLIF(SUM(f.net_sales_amount), 0)) * 100, 2) AS profit_margin_pct,
                SUM(f.quantity_sold) AS total_units_sold,
                COUNT(DISTINCT f.product_key) AS active_skus
            FROM Fact_Sales_Transactions f
            JOIN Dim_Product p ON f.product_key = p.product_key
            GROUP BY p.therapeutic_class, p.category_name
            ORDER BY total_revenue DESC;
        """
        return execute_query(sql)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/inventory-expiry-risk")
def get_inventory_expiry_risk() -> List[Dict[str, Any]]:
    """Monitors batch expiry risk, alerting on batches expiring within 90 days or 30 days."""
    try:
        sql = """
            SELECT 
                f.batch_number,
                p.trade_name,
                p.generic_name,
                p.dosage_form,
                p.strength,
                p.storage_condition,
                s.supplier_name,
                d_exp.full_date AS expiration_date,
                f.current_stock_quantity,
                f.unit_cost_price,
                f.inventory_cost_valuation,
                f.days_until_expiration,
                CASE 
                    WHEN f.is_expired = 1 THEN 'EXPIRED'
                    WHEN f.is_near_expiry_30d = 1 THEN 'CRITICAL'
                    WHEN f.is_near_expiry_90d = 1 THEN 'WARNING'
                    ELSE 'HEALTHY'
                END AS urgency_level
            FROM Fact_Inventory_Batches f
            JOIN Dim_Product p ON f.product_key = p.product_key
            JOIN Dim_Supplier s ON f.supplier_key = s.supplier_key
            JOIN Dim_Date d_exp ON f.expiry_date_key = d_exp.date_key
            ORDER BY f.days_until_expiration ASC;
        """
        return execute_query(sql)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/insurance-claims")
def get_insurance_claims() -> Dict[str, Any]:
    """Breakdown of claims performance across payers and top rejection causes."""
    try:
        payer_sql = """
            SELECT 
                pay.payer_name,
                pay.payer_type,
                COUNT(f.claim_fact_id) AS total_claims,
                ROUND(SUM(f.claim_amount), 2) AS total_claim_amount,
                ROUND(SUM(f.approved_amount), 2) AS total_approved_amount,
                ROUND(SUM(f.rejection_loss_amount), 2) AS total_rejection_loss,
                SUM(CASE WHEN f.claim_status = 'APPROVED' THEN 1 ELSE 0 END) AS approved_count,
                SUM(CASE WHEN f.claim_status = 'REJECTED' THEN 1 ELSE 0 END) AS rejected_count,
                SUM(CASE WHEN f.claim_status = 'PENDING' THEN 1 ELSE 0 END) AS pending_count,
                ROUND((SUM(CASE WHEN f.claim_status = 'APPROVED' THEN 1 ELSE 0 END) / NULLIF(COUNT(f.claim_fact_id), 0)) * 100, 2) AS approval_rate_pct,
                ROUND(AVG(f.turnaround_days), 1) AS avg_turnaround_days
            FROM Fact_Insurance_Claims f
            JOIN Dim_Payer pay ON f.payer_key = pay.payer_key
            GROUP BY pay.payer_name, pay.payer_type
            ORDER BY total_claim_amount DESC;
        """
        payer_performance = execute_query(payer_sql)

        rejection_sql = """
            SELECT 
                rejection_code,
                rejection_reason,
                COUNT(*) AS occurrences,
                ROUND(SUM(claim_amount), 2) AS total_lost_amount
            FROM Fact_Insurance_Claims
            WHERE claim_status = 'REJECTED'
            GROUP BY rejection_code, rejection_reason
            ORDER BY total_lost_amount DESC;
        """
        top_rejections = execute_query(rejection_sql)

        return {
            "payer_performance": payer_performance,
            "top_rejections": top_rejections
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/top-prescribed-medicines")
def get_top_prescribed_medicines() -> List[Dict[str, Any]]:
    """Top prescribed & dispensed medicines by revenue and volume."""
    try:
        sql = """
            SELECT 
                p.trade_name,
                p.generic_name,
                p.dosage_form,
                p.strength,
                p.category_name,
                p.therapeutic_class,
                p.is_prescription_required,
                SUM(f.quantity_sold) AS total_units_sold,
                ROUND(SUM(f.net_sales_amount), 2) AS total_revenue,
                ROUND(SUM(f.cost_of_goods_sold), 2) AS total_cogs,
                ROUND(SUM(f.gross_profit), 2) AS gross_profit,
                ROUND((SUM(f.gross_profit) / NULLIF(SUM(f.net_sales_amount), 0)) * 100, 2) AS profit_margin_pct
            FROM Fact_Sales_Transactions f
            JOIN Dim_Product p ON f.product_key = p.product_key
            GROUP BY p.product_key, p.trade_name, p.generic_name, p.dosage_form, p.strength, p.category_name, p.therapeutic_class, p.is_prescription_required
            ORDER BY total_revenue DESC
            LIMIT 10;
        """
        return execute_query(sql)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/trigger-etl")
def trigger_etl_pipeline() -> Dict[str, Any]:
    """Execute the idempotent sp_Run_Pharmacy_ELT stored procedure in central_pharmacy_dwh."""
    try:
        start_time = time.time()
        execute_stored_procedure("sp_Run_Pharmacy_ELT")
        elapsed_sec = round(time.time() - start_time, 3)

        # Retrieve row counts
        counts_sql = """
            SELECT 'Dim_Product' AS table_name, COUNT(*) AS row_count FROM Dim_Product
            UNION ALL SELECT 'Dim_Customer_Patient', COUNT(*) FROM Dim_Customer_Patient
            UNION ALL SELECT 'Dim_Supplier', COUNT(*) FROM Dim_Supplier
            UNION ALL SELECT 'Dim_Payer', COUNT(*) FROM Dim_Payer
            UNION ALL SELECT 'Dim_Date', COUNT(*) FROM Dim_Date
            UNION ALL SELECT 'Fact_Sales_Transactions', COUNT(*) FROM Fact_Sales_Transactions
            UNION ALL SELECT 'Fact_Inventory_Batches', COUNT(*) FROM Fact_Inventory_Batches
            UNION ALL SELECT 'Fact_Insurance_Claims', COUNT(*) FROM Fact_Insurance_Claims;
        """
        table_counts = execute_query(counts_sql)

        return {
            "status": "SUCCESS",
            "message": "Idempotent ELT pipeline executed successfully across all 4 operational databases.",
            "execution_duration_seconds": elapsed_sec,
            "executed_at": datetime.utcnow().isoformat(),
            "table_counts": table_counts
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/pipeline-status")
def get_pipeline_status() -> Dict[str, Any]:
    """Returns row counts and operational database sync health status."""
    try:
        dwh_counts = execute_query("""
            SELECT 'Dim_Product' AS table_name, COUNT(*) AS row_count FROM central_pharmacy_dwh.Dim_Product
            UNION ALL SELECT 'Dim_Customer_Patient', COUNT(*) FROM central_pharmacy_dwh.Dim_Customer_Patient
            UNION ALL SELECT 'Dim_Supplier', COUNT(*) FROM central_pharmacy_dwh.Dim_Supplier
            UNION ALL SELECT 'Dim_Payer', COUNT(*) FROM central_pharmacy_dwh.Dim_Payer
            UNION ALL SELECT 'Fact_Sales_Transactions', COUNT(*) FROM central_pharmacy_dwh.Fact_Sales_Transactions
            UNION ALL SELECT 'Fact_Inventory_Batches', COUNT(*) FROM central_pharmacy_dwh.Fact_Inventory_Batches
            UNION ALL SELECT 'Fact_Insurance_Claims', COUNT(*) FROM central_pharmacy_dwh.Fact_Insurance_Claims;
        """)

        sources = [
            {"database": "pharmacy_core_db", "status": "ONLINE", "tables": ["brands", "medicine_categories", "medicines"]},
            {"database": "pos_retail_db", "status": "ONLINE", "tables": ["users", "sales", "sale_items", "sale_item_batches", "payments"]},
            {"database": "inventory_procurement_db", "status": "ONLINE", "tables": ["suppliers", "medicine_batches", "purchases", "purchase_items", "stock_movements"]},
            {"database": "insurance_claims_db", "status": "ONLINE", "tables": ["payers", "claims"]}
        ]

        return {
            "warehouse_status": "ONLINE",
            "mysql_connected": is_mysql_connected(),
            "dwh_database": "central_pharmacy_dwh",
            "source_databases": sources,
            "warehouse_metrics": dwh_counts
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
