-- ==============================================================================
-- PROJECT: Pharmacy Data Warehouse System (pharmacy-dwh-system)
-- SCRIPT: 02_dwh_star_schema.sql
-- DESCRIPTION: DDL for Warehouse Database 'central_pharmacy_dwh'
--   1. Conformed Dimensions:
--      - Dim_Date
--      - Dim_Product
--      - Dim_Customer_Patient
--      - Dim_Supplier
--      - Dim_Payer
--   2. Fact Tables:
--      - Fact_Sales_Transactions (Grain: Dispensed Item in POS Transaction)
--      - Fact_Inventory_Batches (Grain: Procured Batch Inventory Status)
--      - Fact_Insurance_Claims   (Grain: Claim Lifecycle & Adjudication Event)
-- ==============================================================================

SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS `central_pharmacy_dwh` 
  DEFAULT CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

USE `central_pharmacy_dwh`;

-- Drop Fact tables first due to FK constraints
DROP TABLE IF EXISTS `Fact_Insurance_Claims`;
DROP TABLE IF EXISTS `Fact_Inventory_Batches`;
DROP TABLE IF EXISTS `Fact_Sales_Transactions`;

-- Drop Dimension tables
DROP TABLE IF EXISTS `Dim_Payer`;
DROP TABLE IF EXISTS `Dim_Supplier`;
DROP TABLE IF EXISTS `Dim_Customer_Patient`;
DROP TABLE IF EXISTS `Dim_Product`;
DROP TABLE IF EXISTS `Dim_Date`;

-- ==============================================================================
-- 1. CONFORMED DIMENSIONS
-- ==============================================================================

-- 1.1 Dim_Date
CREATE TABLE `Dim_Date` (
  `date_key` INT PRIMARY KEY COMMENT 'Surrogate Key format YYYYMMDD (e.g., 20261020, 19000101 for Unknown)',
  `full_date` DATE NOT NULL,
  `day_of_week` TINYINT NOT NULL COMMENT '1=Sunday, 2=Monday, ..., 7=Saturday',
  `day_name` VARCHAR(15) NOT NULL,
  `day_of_month` TINYINT NOT NULL,
  `day_of_year` SMALLINT NOT NULL,
  `week_of_year` TINYINT NOT NULL,
  `month_num` TINYINT NOT NULL,
  `month_name` VARCHAR(20) NOT NULL,
  `month_short` CHAR(3) NOT NULL,
  `calendar_quarter` CHAR(2) NOT NULL COMMENT 'Q1, Q2, Q3, Q4',
  `calendar_quarter_num` TINYINT NOT NULL,
  `calendar_year` SMALLINT NOT NULL,
  `is_weekend` BOOLEAN NOT NULL DEFAULT 0,
  `fiscal_year` SMALLINT NOT NULL,
  `fiscal_quarter` CHAR(2) NOT NULL,
  INDEX `idx_dim_date_fulldate` (`full_date`),
  INDEX `idx_dim_date_year_month` (`calendar_year`, `month_num`)
) ENGINE=InnoDB;

-- 1.2 Dim_Product
CREATE TABLE `Dim_Product` (
  `product_key` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate Key',
  `source_medicine_id` INT NOT NULL UNIQUE COMMENT 'Natural / Business Key from pharmacy_core_db',
  `sku_code` VARCHAR(50) NOT NULL UNIQUE,
  `generic_name` VARCHAR(150) NOT NULL,
  `trade_name` VARCHAR(150) NOT NULL,
  `brand_name` VARCHAR(100) NOT NULL,
  `brand_country` VARCHAR(60) NOT NULL,
  `category_name` VARCHAR(100) NOT NULL,
  `therapeutic_class` VARCHAR(100) NOT NULL,
  `dosage_form` VARCHAR(50) NOT NULL,
  `strength` VARCHAR(50) NOT NULL,
  `is_prescription_required` BOOLEAN NOT NULL DEFAULT 0,
  `storage_condition` VARCHAR(50) NOT NULL DEFAULT 'ROOM_TEMP',
  `standard_retail_price` DECIMAL(10,2) NOT NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT 1,
  `etl_loaded_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `etl_updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_dim_product_category` (`category_name`),
  INDEX `idx_dim_product_therapeutic` (`therapeutic_class`)
) ENGINE=InnoDB;

-- 1.3 Dim_Customer_Patient
CREATE TABLE `Dim_Customer_Patient` (
  `customer_key` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate Key',
  `source_user_id` INT NOT NULL UNIQUE COMMENT 'Natural / Business Key from pos_retail_db',
  `full_name` VARCHAR(120) NOT NULL,
  `gender` VARCHAR(10) NOT NULL,
  `date_of_birth` DATE NULL,
  `age_group` VARCHAR(25) NOT NULL COMMENT '<18, 18-35, 36-50, 51-65, 65+, Unknown',
  `city` VARCHAR(80) NOT NULL,
  `user_type` VARCHAR(40) NOT NULL DEFAULT 'PATIENT_CUSTOMER',
  `patient_segment` VARCHAR(50) NOT NULL DEFAULT 'RETAIL_PATIENT',
  `etl_loaded_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `etl_updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_dim_customer_age` (`age_group`),
  INDEX `idx_dim_customer_city` (`city`)
) ENGINE=InnoDB;

-- 1.4 Dim_Supplier
CREATE TABLE `Dim_Supplier` (
  `supplier_key` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate Key',
  `source_supplier_id` INT NOT NULL UNIQUE COMMENT 'Natural / Business Key from inventory_procurement_db',
  `supplier_name` VARCHAR(120) NOT NULL,
  `license_number` VARCHAR(60) NOT NULL,
  `contact_person` VARCHAR(100),
  `country` VARCHAR(60) NOT NULL,
  `city` VARCHAR(60) NOT NULL,
  `payment_terms_days` INT DEFAULT 30,
  `is_active` BOOLEAN DEFAULT 1,
  `etl_loaded_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `etl_updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_dim_supplier_country` (`country`)
) ENGINE=InnoDB;

-- 1.5 Dim_Payer
CREATE TABLE `Dim_Payer` (
  `payer_key` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate Key',
  `source_payer_id` INT NOT NULL UNIQUE COMMENT 'Natural / Business Key from insurance_claims_db',
  `payer_code` VARCHAR(30) NOT NULL UNIQUE,
  `payer_name` VARCHAR(120) NOT NULL,
  `payer_type` VARCHAR(60) NOT NULL,
  `average_turnaround_days` INT DEFAULT 14,
  `is_active` BOOLEAN DEFAULT 1,
  `etl_loaded_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `etl_updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_dim_payer_type` (`payer_type`)
) ENGINE=InnoDB;


-- ==============================================================================
-- 2. FACT TABLES
-- ==============================================================================

-- 2.1 Fact_Sales_Transactions
-- Grain: Individual item dispensed/sold in a POS retail or counter transaction
CREATE TABLE `Fact_Sales_Transactions` (
  `sales_fact_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
  `date_key` INT NOT NULL,
  `product_key` INT NOT NULL,
  `customer_key` INT NOT NULL,
  `supplier_key` INT NOT NULL,
  `payer_key` INT NOT NULL,
  
  -- Degenerate Dimensions (DD)
  `invoice_number` VARCHAR(50) NOT NULL,
  `prescription_number` VARCHAR(50) NULL,
  `doctor_name` VARCHAR(120) NULL,
  `sale_channel` VARCHAR(40) NOT NULL DEFAULT 'COUNTER_WALK_IN',
  `dispensed_batch_number` VARCHAR(50) NULL,
  `payment_method` VARCHAR(40) NOT NULL DEFAULT 'CASH',
  `is_prescription_dispense` BOOLEAN NOT NULL DEFAULT 0,
  
  -- Measures
  `quantity_sold` INT NOT NULL,
  `unit_selling_price` DECIMAL(10,2) NOT NULL,
  `unit_cost_price` DECIMAL(10,2) NOT NULL,
  `gross_sales_amount` DECIMAL(12,2) NOT NULL,
  `discount_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `tax_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `net_sales_amount` DECIMAL(12,2) NOT NULL COMMENT 'gross_sales_amount - discount_amount',
  `cost_of_goods_sold` DECIMAL(12,2) NOT NULL COMMENT 'quantity_sold * unit_cost_price',
  `gross_profit` DECIMAL(12,2) NOT NULL COMMENT 'net_sales_amount - cost_of_goods_sold',
  `profit_margin_pct` DECIMAL(5,2) NOT NULL COMMENT '(gross_profit / net_sales_amount) * 100',
  
  -- Audit
  `etl_loaded_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  -- Foreign Key Constraints
  CONSTRAINT `fk_facts_date` FOREIGN KEY (`date_key`) REFERENCES `Dim_Date` (`date_key`),
  CONSTRAINT `fk_facts_product` FOREIGN KEY (`product_key`) REFERENCES `Dim_Product` (`product_key`),
  CONSTRAINT `fk_facts_customer` FOREIGN KEY (`customer_key`) REFERENCES `Dim_Customer_Patient` (`customer_key`),
  CONSTRAINT `fk_facts_supplier` FOREIGN KEY (`supplier_key`) REFERENCES `Dim_Supplier` (`supplier_key`),
  CONSTRAINT `fk_facts_payer` FOREIGN KEY (`payer_key`) REFERENCES `Dim_Payer` (`payer_key`),
  
  -- Performance Indexes
  INDEX `idx_fact_sales_date` (`date_key`),
  INDEX `idx_fact_sales_product` (`product_key`),
  INDEX `idx_fact_sales_customer` (`customer_key`),
  INDEX `idx_fact_sales_payer` (`payer_key`),
  INDEX `idx_fact_sales_invoice` (`invoice_number`),
  INDEX `idx_fact_sales_rx` (`prescription_number`)
) ENGINE=InnoDB;

-- 2.2 Fact_Inventory_Batches
-- Grain: Individual procured batch unit monitored in warehouse / pharmacy inventory
CREATE TABLE `Fact_Inventory_Batches` (
  `inventory_fact_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
  `received_date_key` INT NOT NULL,
  `expiry_date_key` INT NOT NULL,
  `product_key` INT NOT NULL,
  `supplier_key` INT NOT NULL,
  
  -- Degenerate Dimensions
  `batch_number` VARCHAR(50) NOT NULL UNIQUE,
  `storage_condition` VARCHAR(50) NOT NULL DEFAULT 'ROOM_TEMP',
  `quality_inspection_status` VARCHAR(30) NOT NULL DEFAULT 'PASSED',
  
  -- Measures
  `initial_quantity` INT NOT NULL,
  `current_stock_quantity` INT NOT NULL,
  `dispensed_quantity` INT NOT NULL,
  `unit_cost_price` DECIMAL(10,2) NOT NULL,
  `mrp_price` DECIMAL(10,2) NOT NULL,
  `inventory_cost_valuation` DECIMAL(14,2) NOT NULL COMMENT 'current_stock_quantity * unit_cost_price',
  `inventory_retail_valuation` DECIMAL(14,2) NOT NULL COMMENT 'current_stock_quantity * mrp_price',
  `potential_margin_valuation` DECIMAL(14,2) NOT NULL COMMENT 'inventory_retail_valuation - inventory_cost_valuation',
  `days_until_expiration` INT NOT NULL,
  `is_expired` BOOLEAN NOT NULL DEFAULT 0,
  `is_near_expiry_90d` BOOLEAN NOT NULL DEFAULT 0,
  `is_near_expiry_30d` BOOLEAN NOT NULL DEFAULT 0,
  
  -- Audit
  `etl_loaded_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  -- Foreign Key Constraints
  CONSTRAINT `fk_fact_inv_rec_date` FOREIGN KEY (`received_date_key`) REFERENCES `Dim_Date` (`date_key`),
  CONSTRAINT `fk_fact_inv_exp_date` FOREIGN KEY (`expiry_date_key`) REFERENCES `Dim_Date` (`date_key`),
  CONSTRAINT `fk_fact_inv_product` FOREIGN KEY (`product_key`) REFERENCES `Dim_Product` (`product_key`),
  CONSTRAINT `fk_fact_inv_supplier` FOREIGN KEY (`supplier_key`) REFERENCES `Dim_Supplier` (`supplier_key`),
  
  -- Performance Indexes
  INDEX `idx_fact_inv_rec_date` (`received_date_key`),
  INDEX `idx_fact_inv_exp_date` (`expiry_date_key`),
  INDEX `idx_fact_inv_product` (`product_key`),
  INDEX `idx_fact_inv_supplier` (`supplier_key`),
  INDEX `idx_fact_inv_near_exp` (`is_near_expiry_90d`, `is_expired`)
) ENGINE=InnoDB;

-- 2.3 Fact_Insurance_Claims
-- Grain: Insurance claim adjudication and lifecycle event
CREATE TABLE `Fact_Insurance_Claims` (
  `claim_fact_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
  `submission_date_key` INT NOT NULL,
  `adjudication_date_key` INT NOT NULL,
  `product_key` INT NOT NULL,
  `customer_key` INT NOT NULL,
  `payer_key` INT NOT NULL,
  
  -- Degenerate Dimensions
  `claim_reference_number` VARCHAR(60) NOT NULL UNIQUE,
  `pos_invoice_number` VARCHAR(50) NOT NULL,
  `patient_policy_number` VARCHAR(50) NOT NULL,
  `patient_member_id` VARCHAR(50) NOT NULL,
  `prescription_number` VARCHAR(50) NOT NULL,
  `claim_status` ENUM('APPROVED', 'REJECTED', 'PENDING') NOT NULL,
  `rejection_code` VARCHAR(50) NULL,
  `rejection_reason` VARCHAR(255) NULL,
  
  -- Measures
  `claim_amount` DECIMAL(12,2) NOT NULL,
  `copay_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `approved_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `settlement_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `rejection_loss_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT 'claim_amount if REJECTED else 0',
  `turnaround_days` INT NOT NULL DEFAULT 0,
  `approval_rate_pct` DECIMAL(5,2) NOT NULL,
  
  -- Audit
  `etl_loaded_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  -- Foreign Key Constraints
  CONSTRAINT `fk_fact_claims_sub_date` FOREIGN KEY (`submission_date_key`) REFERENCES `Dim_Date` (`date_key`),
  CONSTRAINT `fk_fact_claims_adj_date` FOREIGN KEY (`adjudication_date_key`) REFERENCES `Dim_Date` (`date_key`),
  CONSTRAINT `fk_fact_claims_product` FOREIGN KEY (`product_key`) REFERENCES `Dim_Product` (`product_key`),
  CONSTRAINT `fk_fact_claims_customer` FOREIGN KEY (`customer_key`) REFERENCES `Dim_Customer_Patient` (`customer_key`),
  CONSTRAINT `fk_fact_claims_payer` FOREIGN KEY (`payer_key`) REFERENCES `Dim_Payer` (`payer_key`),
  
  -- Performance Indexes
  INDEX `idx_fact_claims_sub_date` (`submission_date_key`),
  INDEX `idx_fact_claims_adj_date` (`adjudication_date_key`),
  INDEX `idx_fact_claims_payer` (`payer_key`),
  INDEX `idx_fact_claims_customer` (`customer_key`),
  INDEX `idx_fact_claims_status` (`claim_status`),
  INDEX `idx_fact_claims_rejection` (`rejection_code`)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- ==============================================================================
-- End of 02_dwh_star_schema.sql
-- ==============================================================================
