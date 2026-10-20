# Pharmacy Data Warehouse & Business Intelligence System (`pharmacy-dwh-system`)

An enterprise-grade, end-to-end Healthcare & Pharmacy Data Warehouse monorepo implementing **Ralph Kimball Star Schema** architecture. Extracts heterogeneous operational data from 4 transactional source databases, processes them via an **idempotent ELT pipeline**, and powers executive analytical dashboards through a **FastAPI** backend and **React 18 + Vite + Tailwind CSS** frontend.

---

## 🏗️ Monorepo Architecture

```
pharmacy-data-warehouse/
├── database/
│   ├── 01_sources_ddl_and_seed.sql      # 4 Operational 3NF OLTP source databases & realistic seed data
│   ├── 02_dwh_star_schema.sql           # Kimball Star Schema: 5 Conformed Dimensions + 3 Fact Tables
│   └── 03_etl_pipeline.sql              # Idempotent ELT Stored Procedure & surrogate key resolution
├── backend/
│   ├── main.py                          # FastAPI application entry point with CORS & Health routes
│   ├── database.py                      # MySQL connection pool & analytical query engine
│   ├── requirements.txt                 # Backend dependencies (fastapi, uvicorn, mysql-connector)
│   ├── .env                             # MySQL connection configuration
│   └── routers/
│       └── analytics.py                 # REST endpoints (KPI summary, Sales trend, Expiry, Claims)
├── frontend/
│   ├── package.json                     # React 18, Vite, Tailwind CSS, Lucide React, Recharts
│   ├── vite.config.js                   # Vite config with API proxy
│   ├── tailwind.config.js               # Healthcare color scheme & dark mode styling
│   ├── index.html                       # Responsive HTML5 entry point
│   └── src/
│       ├── main.jsx                     # React root
│       ├── index.css                    # Glassmorphism design tokens & neon glow accents
│       └── App.jsx                      # Executive Data Warehouse Intelligence Dashboard
└── README.md
```

---

## 🗄️ Database Architecture

### Step 1: 4 Operational Source Databases (`01_sources_ddl_and_seed.sql`)

| Operational Database | Tables | Description |
|----------------------|--------|-------------|
| **`pharmacy_core_db`** | `brands`, `medicine_categories`, `medicines` | Master pharmaceutical formulary, therapeutic classifications, and realistic dosage formulations. |
| **`pos_retail_db`** | `users`, `sales`, `sale_items`, `sale_item_batches`, `payments` | Point-of-Sale counter receipts with mixed OTC and Doctor Prescriptions, batch lot allocations, and payment channels. |
| **`inventory_procurement_db`** | `suppliers`, `medicine_batches`, `purchases`, `purchase_items`, `stock_movements` | Supply chain procurement, unit cost prices, manufacturing/expiry dates, storage conditions (e.g., Cold Chain 2-8°C), and inventory ledgers. |
| **`insurance_claims_db`** | `payers`, `claims` | Payer registries (BCBS, OptumRx/UNH, Medicare Part D, Aetna, Cigna) and claim lifecycle adjudications (`APPROVED`, `REJECTED`, `PENDING`). |

---

### Step 2: Warehouse Database `central_pharmacy_dwh` (`02_dwh_star_schema.sql`)

#### Conformed Dimensions
1. **`Dim_Date`**: Calendar surrogate key (`YYYYMMDD`), covering 2023–2030, fiscal quarters, day names, weekend flags, plus default record `19000101` for unknown dates.
2. **`Dim_Product`**: Conformed medicine catalog linking generic name, brand name, manufacturer country, therapeutic class, strength, dosage form, and retail price.
3. **`Dim_Customer_Patient`**: Patient demographics, derived age groups (`<18`, `18-35`, `36-50`, `51-65`, `65+`), and patient categories.
4. **`Dim_Supplier`**: Procurement vendor details, licensing, and credit terms.
5. **`Dim_Payer`**: Insurance payers, coverage classification, and turnaround service levels.

#### Fact Tables
1. **`Fact_Sales_Transactions`**
   - **Grain**: Individual item dispensed/sold in a POS transaction.
   - **Measures**: `quantity_sold`, `unit_selling_price`, `unit_cost_price`, `gross_sales_amount`, `discount_amount`, `net_sales_amount`, `cost_of_goods_sold` (COGS), `gross_profit`, `profit_margin_pct`.
   - **Foreign Keys**: `date_key`, `product_key`, `customer_key`, `supplier_key`, `payer_key`.

2. **`Fact_Inventory_Batches`**
   - **Grain**: Batch received and monitored in pharmacy/warehouse inventory.
   - **Measures**: `initial_quantity`, `current_stock_quantity`, `dispensed_quantity`, `unit_cost_price`, `inventory_cost_valuation`, `days_until_expiration`, `is_expired`, `is_near_expiry_90d`, `is_near_expiry_30d`.

3. **`Fact_Insurance_Claims`**
   - **Grain**: Insurance claim adjudication event and lifecycle outcome.
   - **Measures**: `claim_amount`, `copay_amount`, `approved_amount`, `settlement_amount`, `rejection_loss_amount`, `turnaround_days`, `approval_rate_pct`.

---

### Step 3: Master Idempotent ELT Pipeline (`03_etl_pipeline.sql`)

The stored procedure `sp_Run_Pharmacy_ELT()` is fully idempotent:
- Can be executed multiple times safely without duplicate key violations.
- Extracts directly across the 4 source operational schemas into `central_pharmacy_dwh`.
- Performs surrogate key lookups with fallbacks to conformed unknown member records (`product_key = 1`, `customer_key = 1`, `supplier_key = 1`, `payer_key = 1`, `date_key = 19000101`).
- Dynamically computes COGS, profit margins, batch expiry urgency days, and insurance rejection losses.

---

## 🚀 Running the Project

### 1. Database Setup (MySQL 8.0)
Execute the 3 SQL scripts in sequence:
```bash
# 1. Operational source databases & seed data
mysql -u root -p < database/01_sources_ddl_and_seed.sql

# 2. Central warehouse star schema
mysql -u root -p < database/02_dwh_star_schema.sql

# 3. Master ELT pipeline extraction & loading
mysql -u root -p < database/03_etl_pipeline.sql
```

### 2. Backend Setup (FastAPI)
```bash
cd backend
pip install -r requirements.txt
uvicorn backend.main:app --reload --port 8000
```
API Documentation will be accessible at: `http://localhost:8000/docs`

### 3. Frontend Setup (React + Vite)
```bash
cd frontend
npm install
npm run dev
```
Dashboard will be accessible at: `http://localhost:5173`