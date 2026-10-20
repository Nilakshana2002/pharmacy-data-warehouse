"""
Pharmacy Data Warehouse Analytics Router
Module: backend/routers/analytics.py
Serves analytical OLAP aggregations from central_pharmacy_dwh
"""

from fastapi import APIRouter, HTTPException, Query
from typing import Dict, Any, List, Optional
from datetime import datetime
from backend.database import execute_query, execute_procedure

router = APIRouter(prefix="/api/analytics", tags=["analytics"])


# ==============================================================================
# 1. High-Level KPIs
# ==============================================================================
@router.get("/kpis")
def get_kpis() -> Dict[str, Any]:
    """
    Returns high-level executive metrics from central_pharmacy_dwh:
    - total net revenue
    - total COGS
    - net profit margin %
    - total pending and rejected claims value
    - count of batches expiring within 180 days
    """
    try:
        # Sales & Financial aggregations
        sales_sql = """
            SELECT 
                ROUND(COALESCE(SUM(net_sales_amount), 0), 2) AS total_net_revenue,
                ROUND(COALESCE(SUM(cost_of_goods_sold), 0), 2) AS total_cogs,
                ROUND(COALESCE(SUM(gross_profit), 0), 2) AS total_gross_profit,
                ROUND(COALESCE((SUM(gross_profit) / NULLIF(SUM(net_sales_amount), 0)) * 100, 0), 2) AS net_profit_margin_pct,
                COALESCE(SUM(quantity_sold), 0) AS total_units_sold,
                COUNT(DISTINCT invoice_number) AS total_transactions,
                COALESCE(SUM(is_prescription_dispense), 0) AS rx_dispensed_count
            FROM Fact_Sales_Transactions;
        """
        sales_metrics = execute_query(sales_sql)[0]

        # Insurance Claims aggregations
        claims_sql = """
            SELECT 
                ROUND(COALESCE(SUM(CASE WHEN claim_status = 'PENDING' THEN claim_amount ELSE 0 END), 0), 2) AS total_pending_claims_value,
                ROUND(COALESCE(SUM(CASE WHEN claim_status = 'REJECTED' THEN claim_amount ELSE 0 END), 0), 2) AS total_rejected_claims_value,
                ROUND(COALESCE(SUM(CASE WHEN claim_status IN ('PENDING', 'REJECTED') THEN claim_amount ELSE 0 END), 0), 2) AS total_pending_rejected_claims_value,
                ROUND(COALESCE(SUM(claim_amount), 0), 2) AS total_claims_submitted_value,
                ROUND(COALESCE(SUM(approved_amount), 0), 2) AS total_approved_claims_value,
                SUM(CASE WHEN claim_status = 'APPROVED' THEN 1 ELSE 0 END) AS approved_count,
                SUM(CASE WHEN claim_status = 'REJECTED' THEN 1 ELSE 0 END) AS rejected_count,
                SUM(CASE WHEN claim_status = 'PENDING' THEN 1 ELSE 0 END) AS pending_count,
                COUNT(*) AS total_claims_count
            FROM Fact_Insurance_Claims;
        """
        claims_metrics = execute_query(claims_sql)[0]

        # Batch Inventory & Expiry aggregations (within 180 days)
        inventory_sql = """
            SELECT 
                COUNT(CASE WHEN days_until_expiration BETWEEN 0 AND 180 THEN 1 END) AS batches_expiring_within_180_days,
                COUNT(CASE WHEN days_until_expiration BETWEEN 0 AND 90 THEN 1 END) AS batches_expiring_within_90_days,
                COUNT(CASE WHEN days_until_expiration BETWEEN 0 AND 30 THEN 1 END) AS batches_expiring_within_30_days,
                COUNT(CASE WHEN is_expired = 1 THEN 1 END) AS expired_batches_count,
                ROUND(COALESCE(SUM(CASE WHEN days_until_expiration BETWEEN 0 AND 180 THEN inventory_cost_valuation ELSE 0 END), 0), 2) AS valuation_expiring_180_days,
                ROUND(COALESCE(SUM(inventory_cost_valuation), 0), 2) AS total_inventory_valuation,
                COUNT(*) AS total_batches_tracked
            FROM Fact_Inventory_Batches;
        """
        inventory_metrics = execute_query(inventory_sql)[0]

        return {
            "status": "SUCCESS",
            "dwh_target": "central_pharmacy_dwh",
            "timestamp": datetime.utcnow().isoformat(),
            "kpis": {
                "total_net_revenue": sales_metrics["total_net_revenue"],
                "total_cogs": sales_metrics["total_cogs"],
                "total_gross_profit": sales_metrics["total_gross_profit"],
                "net_profit_margin_pct": sales_metrics["net_profit_margin_pct"],
                "total_pending_claims_value": claims_metrics["total_pending_claims_value"],
                "total_rejected_claims_value": claims_metrics["total_rejected_claims_value"],
                "total_pending_rejected_claims_value": claims_metrics["total_pending_rejected_claims_value"],
                "batches_expiring_within_180_days": inventory_metrics["batches_expiring_within_180_days"],
                "valuation_expiring_180_days": inventory_metrics["valuation_expiring_180_days"],
                "expired_batches_count": inventory_metrics["expired_batches_count"],
                "total_inventory_valuation": inventory_metrics["total_inventory_valuation"],
                "total_units_sold": sales_metrics["total_units_sold"],
                "total_transactions": sales_metrics["total_transactions"],
                "total_claims_count": claims_metrics["total_claims_count"]
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


# Alias for backwards compatibility with earlier dashboard requests
@router.get("/kpi-summary")
def get_kpi_summary():
    return get_kpis()


# ==============================================================================
# 2. Profitability (Daily / Monthly Revenue vs. COGS by Sales Channel)
# ==============================================================================
@router.get("/profitability")
def get_profitability(period: str = Query("monthly", regex="^(daily|monthly)$")) -> Dict[str, Any]:
    """
    Returns daily or monthly revenue vs. COGS broken down by sales channel:
    'Prescription Dispensed' vs 'OTC Retail'.
    """
    try:
        if period == "daily":
            time_select = "d.full_date AS period_date, DATE_FORMAT(d.full_date, '%Y-%m-%d') AS period_label"
            time_group = "d.full_date"
            time_order = "d.full_date ASC"
        else:
            time_select = "d.calendar_year, d.month_num, d.month_short, CONCAT(d.calendar_year, '-', LPAD(d.month_num, 2, '0')) AS period_label"
            time_group = "d.calendar_year, d.month_num, d.month_short"
            time_order = "d.calendar_year ASC, d.month_num ASC"

        sql = f"""
            SELECT 
                {time_select},
                CASE 
                    WHEN f.is_prescription_dispense = 1 THEN 'Prescription Dispensed'
                    ELSE 'OTC Retail'
                END AS sales_channel,
                ROUND(SUM(f.net_sales_amount), 2) AS total_revenue,
                ROUND(SUM(f.cost_of_goods_sold), 2) AS total_cogs,
                ROUND(SUM(f.gross_profit), 2) AS gross_profit,
                ROUND((SUM(f.gross_profit) / NULLIF(SUM(f.net_sales_amount), 0)) * 100, 2) AS profit_margin_pct,
                SUM(f.quantity_sold) AS units_dispensed,
                COUNT(DISTINCT f.invoice_number) AS transaction_count
            FROM Fact_Sales_Transactions f
            JOIN Dim_Date d ON f.date_key = d.date_key
            GROUP BY 
                {time_group},
                CASE WHEN f.is_prescription_dispense = 1 THEN 'Prescription Dispensed' ELSE 'OTC Retail' END
            ORDER BY 
                {time_order}, sales_channel ASC;
        """
        trends = execute_query(sql)

        # Overall summary by channel
        channel_summary_sql = """
            SELECT 
                CASE 
                    WHEN is_prescription_dispense = 1 THEN 'Prescription Dispensed'
                    ELSE 'OTC Retail'
                END AS sales_channel,
                ROUND(SUM(net_sales_amount), 2) AS total_revenue,
                ROUND(SUM(cost_of_goods_sold), 2) AS total_cogs,
                ROUND(SUM(gross_profit), 2) AS gross_profit,
                ROUND((SUM(gross_profit) / NULLIF(SUM(net_sales_amount), 0)) * 100, 2) AS profit_margin_pct,
                SUM(quantity_sold) AS units_dispensed,
                COUNT(DISTINCT invoice_number) AS transaction_count
            FROM Fact_Sales_Transactions
            GROUP BY CASE WHEN is_prescription_dispense = 1 THEN 'Prescription Dispensed' ELSE 'OTC Retail' END;
        """
        channel_summary = execute_query(channel_summary_sql)

        return {
            "period": period,
            "channel_summary": channel_summary,
            "time_series": trends
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Profitability query error: {str(e)}")


# ==============================================================================
# 3. Inventory Alerts (Low Stock or Expiring within 180 Days)
# ==============================================================================
@router.get("/inventory-alerts")
def get_inventory_alerts(
    days_threshold: int = Query(180, description="Expiration threshold in days"),
    stock_threshold: int = Query(50, description="Low stock threshold units")
) -> List[Dict[str, Any]]:
    """
    Returns products with stock below threshold OR batches expiring within specified days (default 180),
    including supplier details and replacement cost.
    """
    try:
        sql = """
            SELECT 
                fib.batch_number,
                dp.sku_code,
                dp.trade_name,
                dp.generic_name,
                dp.dosage_form,
                dp.strength,
                dp.category_name,
                dp.therapeutic_class,
                dp.storage_condition,
                ds.supplier_name,
                ds.contact_person AS supplier_contact,
                ds.country AS supplier_country,
                ds.payment_terms_days,
                dd_exp.full_date AS expiration_date,
                fib.current_stock_quantity,
                fib.unit_cost_price AS replacement_unit_cost,
                ROUND(fib.current_stock_quantity * fib.unit_cost_price, 2) AS total_replacement_cost,
                fib.days_until_expiration,
                CASE 
                    WHEN fib.is_expired = 1 THEN 'EXPIRED'
                    WHEN fib.current_stock_quantity = 0 THEN 'OUT_OF_STOCK'
                    WHEN fib.days_until_expiration <= 30 THEN 'CRITICAL_EXPIRY_30D'
                    WHEN fib.days_until_expiration <= 90 THEN 'NEAR_EXPIRY_90D'
                    WHEN fib.days_until_expiration <= :days_threshold THEN 'EXPIRING_SOON_180D'
                    WHEN fib.current_stock_quantity <= :stock_threshold THEN 'LOW_STOCK'
                    ELSE 'NORMAL'
                END AS alert_type,
                CASE 
                    WHEN fib.is_expired = 1 OR fib.days_until_expiration <= 30 OR fib.current_stock_quantity = 0 THEN 'CRITICAL'
                    WHEN fib.days_until_expiration <= 90 OR fib.current_stock_quantity <= :stock_threshold THEN 'WARNING'
                    ELSE 'INFO'
                END AS alert_severity
            FROM Fact_Inventory_Batches fib
            JOIN Dim_Product dp ON fib.product_key = dp.product_key
            JOIN Dim_Supplier ds ON fib.supplier_key = ds.supplier_key
            JOIN Dim_Date dd_exp ON fib.expiry_date_key = dd_exp.date_key
            WHERE fib.days_until_expiration <= :days_threshold 
               OR fib.current_stock_quantity <= :stock_threshold
            ORDER BY fib.days_until_expiration ASC, fib.current_stock_quantity ASC;
        """
        return execute_query(sql, {"days_threshold": days_threshold, "stock_threshold": stock_threshold})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inventory alerts query error: {str(e)}")


# ==============================================================================
# 4. Claims Summary (Payer & Status Breakdown with Rejection Reasons)
# ==============================================================================
@router.get("/claims-summary")
def get_claims_summary() -> Dict[str, Any]:
    """
    Returns insurance claims grouped by payer and status ('APPROVED', 'REJECTED', 'PENDING'),
    with amounts and top rejection reasons.
    """
    try:
        # Payer + Status cross-tabulation
        payer_status_sql = """
            SELECT 
                pay.payer_code,
                pay.payer_name,
                pay.payer_type,
                fic.claim_status,
                COUNT(fic.claim_fact_id) AS claims_count,
                ROUND(SUM(fic.claim_amount), 2) AS total_claim_amount,
                ROUND(SUM(fic.copay_amount), 2) AS total_copay_amount,
                ROUND(SUM(fic.approved_amount), 2) AS total_approved_amount,
                ROUND(SUM(fic.rejection_loss_amount), 2) AS total_rejection_loss,
                ROUND(AVG(fic.turnaround_days), 1) AS avg_turnaround_days
            FROM Fact_Insurance_Claims fic
            JOIN Dim_Payer pay ON fic.payer_key = pay.payer_key
            GROUP BY pay.payer_code, pay.payer_name, pay.payer_type, fic.claim_status
            ORDER BY pay.payer_name ASC, fic.claim_status ASC;
        """
        payer_breakdown = execute_query(payer_status_sql)

        # Status rollup
        status_totals_sql = """
            SELECT 
                claim_status,
                COUNT(*) AS total_count,
                ROUND(SUM(claim_amount), 2) AS total_amount,
                ROUND(SUM(approved_amount), 2) AS total_approved,
                ROUND(SUM(rejection_loss_amount), 2) AS total_loss,
                ROUND(AVG(turnaround_days), 1) AS avg_turnaround_days
            FROM Fact_Insurance_Claims
            GROUP BY claim_status;
        """
        status_totals = execute_query(status_totals_sql)

        # Top rejection reasons
        rejection_sql = """
            SELECT 
                rejection_code,
                rejection_reason,
                COUNT(*) AS rejection_count,
                ROUND(SUM(claim_amount), 2) AS total_lost_amount
            FROM Fact_Insurance_Claims
            WHERE claim_status = 'REJECTED'
            GROUP BY rejection_code, rejection_reason
            ORDER BY total_lost_amount DESC;
        """
        top_rejections = execute_query(rejection_sql)

        return {
            "status_totals": status_totals,
            "claims_by_payer_and_status": payer_breakdown,
            "top_rejection_reasons": top_rejections
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Claims summary query error: {str(e)}")


# ==============================================================================
# Supplementary Analytical Endpoints for Dashboard
# ==============================================================================
@router.get("/sales-trend")
def get_sales_trend():
    """Monthly sales trend helper."""
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


@router.get("/category-performance")
def get_category_performance():
    """Therapeutic category margins helper."""
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


@router.get("/top-prescribed-medicines")
def get_top_prescribed_medicines():
    """Top prescribed medications."""
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


@router.post("/trigger-etl")
def trigger_etl():
    """Triggers the idempotent sp_Run_Pharmacy_ELT stored procedure."""
    try:
        execute_procedure("sp_Run_Pharmacy_ELT")
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
            "executed_at": datetime.utcnow().isoformat(),
            "table_counts": table_counts
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ELT trigger error: {str(e)}")
