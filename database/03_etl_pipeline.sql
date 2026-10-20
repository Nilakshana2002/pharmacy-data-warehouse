-- ==============================================================================
-- PROJECT: Pharmacy Data Warehouse System (pharmacy-dwh-system)
-- SCRIPT: 03_etl_pipeline.sql
-- DESCRIPTION: Idempotent ELT Pipeline extracting data from 4 operational
--   databases, transforming & cleaning data, performing surrogate key lookups,
--   and loading into central_pharmacy_dwh star schema dimensions & fact tables.
-- ==============================================================================

USE `central_pharmacy_dwh`;

-- Temporarily disable FK checks during initialization of default surrogate records
SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------------------------
-- 1. SEED DEFAULT / UNKNOWN DIMENSION RECORDS (Surrogate Key = 0 or 19000101)
-- ------------------------------------------------------------------------------
-- Dim_Date Unknown Record
INSERT INTO `Dim_Date` (
  `date_key`, `full_date`, `day_of_week`, `day_name`, `day_of_month`,
  `day_of_year`, `week_of_year`, `month_num`, `month_name`, `month_short`,
  `calendar_quarter`, `calendar_quarter_num`, `calendar_year`, `is_weekend`,
  `fiscal_year`, `fiscal_quarter`
) VALUES (
  19000101, '1900-01-01', 2, 'Monday', 1, 1, 1, 1, 'January', 'Jan', 'Q1', 1, 1900, 0, 1900, 'Q1'
) ON DUPLICATE KEY UPDATE `day_name` = 'Monday';

-- Dim_Product Default Record (product_key = 1 reserved for Unknown)
INSERT INTO `Dim_Product` (
  `product_key`, `source_medicine_id`, `sku_code`, `generic_name`, `trade_name`,
  `brand_name`, `brand_country`, `category_name`, `therapeutic_class`,
  `dosage_form`, `strength`, `is_prescription_required`, `storage_condition`,
  `standard_retail_price`, `is_active`
) VALUES (
  1, 0, 'SKU-UNKNOWN', 'Unknown Generic Formulation', 'Unknown Trade Name',
  'Generic / Unknown', 'Global', 'General Care', 'Unclassified',
  'Unit', 'N/A', 0, 'ROOM_TEMP', 0.00, 1
) ON DUPLICATE KEY UPDATE `generic_name` = 'Unknown Generic Formulation';

-- Dim_Customer_Patient Default Record
INSERT INTO `Dim_Customer_Patient` (
  `customer_key`, `source_user_id`, `full_name`, `gender`, `date_of_birth`,
  `age_group`, `city`, `user_type`, `patient_segment`
) VALUES (
  1, 0, 'Walk-in Anonymous Patient', 'OTHER', '1990-01-01',
  'Unknown', 'Metropolis', 'PATIENT_CUSTOMER', 'WALK_IN_CASUAL'
) ON DUPLICATE KEY UPDATE `full_name` = 'Walk-in Anonymous Patient';

-- Dim_Supplier Default Record
INSERT INTO `Dim_Supplier` (
  `supplier_key`, `source_supplier_id`, `supplier_name`, `license_number`,
  `contact_person`, `country`, `city`, `payment_terms_days`, `is_active`
) VALUES (
  1, 0, 'Direct Procurement / Unknown Supplier', 'LIC-UNKNOWN',
  'Procurement Office', 'Unknown', 'Metropolis', 30, 1
) ON DUPLICATE KEY UPDATE `supplier_name` = 'Direct Procurement / Unknown Supplier';

-- Dim_Payer Default Record
INSERT INTO `Dim_Payer` (
  `payer_key`, `source_payer_id`, `payer_code`, `payer_name`, `payer_type`,
  `average_turnaround_days`, `is_active`
) VALUES (
  1, 0, 'SELF-PAY', 'Direct Patient Cash / Self-Pay', 'SELF_PAY', 0, 1
) ON DUPLICATE KEY UPDATE `payer_name` = 'Direct Patient Cash / Self-Pay';

SET FOREIGN_KEY_CHECKS = 1;


-- ------------------------------------------------------------------------------
-- 2. POPULATE DIM_DATE (Calendar Range 2024-01-01 through 2028-12-31)
-- ------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_Populate_Dim_Date`;
DELIMITER $$
CREATE PROCEDURE `sp_Populate_Dim_Date`(IN start_date DATE, IN end_date DATE)
BEGIN
  DECLARE cur_date DATE;
  SET cur_date = start_date;
  
  WHILE cur_date <= end_date DO
    INSERT INTO `Dim_Date` (
      `date_key`,
      `full_date`,
      `day_of_week`,
      `day_name`,
      `day_of_month`,
      `day_of_year`,
      `week_of_year`,
      `month_num`,
      `month_name`,
      `month_short`,
      `calendar_quarter`,
      `calendar_quarter_num`,
      `calendar_year`,
      `is_weekend`,
      `fiscal_year`,
      `fiscal_quarter`
    ) VALUES (
      CAST(DATE_FORMAT(cur_date, '%Y%m%d') AS UNSIGNED),
      cur_date,
      DAYOFWEEK(cur_date),
      DAYNAME(cur_date),
      DAYOFMONTH(cur_date),
      DAYOFYEAR(cur_date),
      WEEKOFYEAR(cur_date),
      MONTH(cur_date),
      MONTHNAME(cur_date),
      DATE_FORMAT(cur_date, '%b'),
      CONCAT('Q', QUARTER(cur_date)),
      QUARTER(cur_date),
      YEAR(cur_date),
      IF(DAYOFWEEK(cur_date) IN (1, 7), 1, 0),
      YEAR(cur_date),
      CONCAT('Q', QUARTER(cur_date))
    )
    ON DUPLICATE KEY UPDATE
      `full_date` = VALUES(`full_date`),
      `is_weekend` = VALUES(`is_weekend`);
      
    SET cur_date = DATE_ADD(cur_date, INTERVAL 1 DAY);
  END WHILE;
END$$
DELIMITER ;

-- Execute Date Dimension Population (2023 to 2030)
CALL `sp_Populate_Dim_Date`('2023-01-01', '2030-12-31');


-- ------------------------------------------------------------------------------
-- 3. STORED PROCEDURE: MASTER IDEMPOTENT ELT PIPELINE
-- ------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_Run_Pharmacy_ELT`;
DELIMITER $$
CREATE PROCEDURE `sp_Run_Pharmacy_ELT`()
BEGIN
  -- ----------------------------------------------------------------------------
  -- STEP 3.1: EXTRACT & LOAD DIM_PRODUCT
  -- Source: pharmacy_core_db (medicines, brands, medicine_categories)
  -- ----------------------------------------------------------------------------
  INSERT INTO `central_pharmacy_dwh`.`Dim_Product` (
    `source_medicine_id`,
    `sku_code`,
    `generic_name`,
    `trade_name`,
    `brand_name`,
    `brand_country`,
    `category_name`,
    `therapeutic_class`,
    `dosage_form`,
    `strength`,
    `is_prescription_required`,
    `storage_condition`,
    `standard_retail_price`,
    `is_active`,
    `etl_loaded_at`
  )
  SELECT 
    m.`medicine_id` AS `source_medicine_id`,
    UPPER(TRIM(m.`sku_code`)) AS `sku_code`,
    TRIM(m.`generic_name`) AS `generic_name`,
    TRIM(m.`trade_name`) AS `trade_name`,
    COALESCE(b.`brand_name`, 'Unknown Brand') AS `brand_name`,
    COALESCE(b.`manufacturer_country`, 'Unknown Country') AS `brand_country`,
    COALESCE(c.`category_name`, 'Unassigned') AS `category_name`,
    COALESCE(c.`therapeutic_class`, 'General') AS `therapeutic_class`,
    m.`dosage_form`,
    m.`strength`,
    COALESCE(c.`is_prescription_required`, 0) AS `is_prescription_required`,
    m.`storage_condition`,
    m.`standard_retail_price`,
    m.`is_active`,
    NOW() AS `etl_loaded_at`
  FROM `pharmacy_core_db`.`medicines` m
  LEFT JOIN `pharmacy_core_db`.`brands` b ON m.`brand_id` = b.`brand_id`
  LEFT JOIN `pharmacy_core_db`.`medicine_categories` c ON m.`category_id` = c.`category_id`
  ON DUPLICATE KEY UPDATE
    `generic_name`            = VALUES(`generic_name`),
    `trade_name`              = VALUES(`trade_name`),
    `brand_name`              = VALUES(`brand_name`),
    `brand_country`           = VALUES(`brand_country`),
    `category_name`           = VALUES(`category_name`),
    `therapeutic_class`       = VALUES(`therapeutic_class`),
    `dosage_form`             = VALUES(`dosage_form`),
    `strength`                = VALUES(`strength`),
    `is_prescription_required`= VALUES(`is_prescription_required`),
    `storage_condition`       = VALUES(`storage_condition`),
    `standard_retail_price`   = VALUES(`standard_retail_price`),
    `is_active`               = VALUES(`is_active`),
    `etl_updated_at`          = NOW();

  -- ----------------------------------------------------------------------------
  -- STEP 3.2: EXTRACT & LOAD DIM_CUSTOMER_PATIENT
  -- Source: pos_retail_db.users
  -- Transformation: Derives age groups and customer segmentation
  -- ----------------------------------------------------------------------------
  INSERT INTO `central_pharmacy_dwh`.`Dim_Customer_Patient` (
    `source_user_id`,
    `full_name`,
    `gender`,
    `date_of_birth`,
    `age_group`,
    `city`,
    `user_type`,
    `patient_segment`,
    `etl_loaded_at`
  )
  SELECT 
    u.`user_id` AS `source_user_id`,
    TRIM(u.`full_name`) AS `full_name`,
    u.`gender`,
    u.`date_of_birth`,
    CASE 
      WHEN u.`date_of_birth` IS NULL THEN 'Unknown'
      WHEN TIMESTAMPDIFF(YEAR, u.`date_of_birth`, CURDATE()) < 18 THEN '<18'
      WHEN TIMESTAMPDIFF(YEAR, u.`date_of_birth`, CURDATE()) BETWEEN 18 AND 35 THEN '18-35'
      WHEN TIMESTAMPDIFF(YEAR, u.`date_of_birth`, CURDATE()) BETWEEN 36 AND 50 THEN '36-50'
      WHEN TIMESTAMPDIFF(YEAR, u.`date_of_birth`, CURDATE()) BETWEEN 51 AND 65 THEN '51-65'
      ELSE '65+'
    END AS `age_group`,
    COALESCE(u.`city`, 'Metropolis') AS `city`,
    u.`user_type`,
    CASE 
      WHEN u.`user_type` != 'PATIENT_CUSTOMER' THEN 'STAFF_MEMBER'
      WHEN TIMESTAMPDIFF(YEAR, u.`date_of_birth`, CURDATE()) >= 60 THEN 'SENIOR_CHRONIC_CARE'
      ELSE 'RETAIL_PATIENT'
    END AS `patient_segment`,
    NOW() AS `etl_loaded_at`
  FROM `pos_retail_db`.`users` u
  ON DUPLICATE KEY UPDATE
    `full_name`       = VALUES(`full_name`),
    `gender`          = VALUES(`gender`),
    `date_of_birth`   = VALUES(`date_of_birth`),
    `age_group`       = VALUES(`age_group`),
    `city`            = VALUES(`city`),
    `user_type`       = VALUES(`user_type`),
    `patient_segment` = VALUES(`patient_segment`),
    `etl_updated_at`  = NOW();

  -- ----------------------------------------------------------------------------
  -- STEP 3.3: EXTRACT & LOAD DIM_SUPPLIER
  -- Source: inventory_procurement_db.suppliers
  -- ----------------------------------------------------------------------------
  INSERT INTO `central_pharmacy_dwh`.`Dim_Supplier` (
    `source_supplier_id`,
    `supplier_name`,
    `license_number`,
    `contact_person`,
    `country`,
    `city`,
    `payment_terms_days`,
    `is_active`,
    `etl_loaded_at`
  )
  SELECT 
    s.`supplier_id` AS `source_supplier_id`,
    TRIM(s.`supplier_name`) AS `supplier_name`,
    s.`license_number`,
    COALESCE(s.`contact_person`, 'N/A') AS `contact_person`,
    COALESCE(s.`country`, 'Global') AS `country`,
    COALESCE(s.`city`, 'Metropolis') AS `city`,
    COALESCE(s.`payment_terms_days`, 30) AS `payment_terms_days`,
    s.`is_active`,
    NOW() AS `etl_loaded_at`
  FROM `inventory_procurement_db`.`suppliers` s
  ON DUPLICATE KEY UPDATE
    `supplier_name`      = VALUES(`supplier_name`),
    `license_number`     = VALUES(`license_number`),
    `contact_person`     = VALUES(`contact_person`),
    `country`            = VALUES(`country`),
    `city`               = VALUES(`city`),
    `payment_terms_days` = VALUES(`payment_terms_days`),
    `is_active`          = VALUES(`is_active`),
    `etl_updated_at`     = NOW();

  -- ----------------------------------------------------------------------------
  -- STEP 3.4: EXTRACT & LOAD DIM_PAYER
  -- Source: insurance_claims_db.payers
  -- ----------------------------------------------------------------------------
  INSERT INTO `central_pharmacy_dwh`.`Dim_Payer` (
    `source_payer_id`,
    `payer_code`,
    `payer_name`,
    `payer_type`,
    `average_turnaround_days`,
    `is_active`,
    `etl_loaded_at`
  )
  SELECT 
    p.`payer_id` AS `source_payer_id`,
    TRIM(p.`payer_code`) AS `payer_code`,
    TRIM(p.`payer_name`) AS `payer_name`,
    p.`payer_type`,
    COALESCE(p.`average_turnaround_days`, 14) AS `average_turnaround_days`,
    p.`is_active`,
    NOW() AS `etl_loaded_at`
  FROM `insurance_claims_db`.`payers` p
  ON DUPLICATE KEY UPDATE
    `payer_code`              = VALUES(`payer_code`),
    `payer_name`              = VALUES(`payer_name`),
    `payer_type`              = VALUES(`payer_type`),
    `average_turnaround_days` = VALUES(`average_turnaround_days`),
    `is_active`               = VALUES(`is_active`),
    `etl_updated_at`          = NOW();

  -- ----------------------------------------------------------------------------
  -- STEP 3.5: EXTRACT & LOAD FACT_SALES_TRANSACTIONS
  -- Grain: Individual item dispensed/sold in POS counter receipt
  -- Features: COGS lookup from inventory batch, profit margin %, surrogate FK mapping
  -- ----------------------------------------------------------------------------
  -- We wipe and reload transactions cleanly to ensure full idempotence
  TRUNCATE TABLE `central_pharmacy_dwh`.`Fact_Sales_Transactions`;

  INSERT INTO `central_pharmacy_dwh`.`Fact_Sales_Transactions` (
    `date_key`,
    `product_key`,
    `customer_key`,
    `supplier_key`,
    `payer_key`,
    `invoice_number`,
    `prescription_number`,
    `doctor_name`,
    `sale_channel`,
    `dispensed_batch_number`,
    `payment_method`,
    `is_prescription_dispense`,
    `quantity_sold`,
    `unit_selling_price`,
    `unit_cost_price`,
    `gross_sales_amount`,
    `discount_amount`,
    `tax_amount`,
    `net_sales_amount`,
    `cost_of_goods_sold`,
    `gross_profit`,
    `profit_margin_pct`,
    `etl_loaded_at`
  )
  SELECT 
    COALESCE(dd.`date_key`, 19000101) AS `date_key`,
    COALESCE(dp.`product_key`, 1) AS `product_key`,
    COALESCE(dc.`customer_key`, 1) AS `customer_key`,
    COALESCE(ds.`supplier_key`, 1) AS `supplier_key`,
    COALESCE(dpay.`payer_key`, 1) AS `payer_key`,
    s.`invoice_number`,
    s.`prescription_number`,
    s.`doctor_name`,
    s.`sale_channel`,
    COALESCE(sib.`batch_number`, 'DEFAULT-LOT') AS `dispensed_batch_number`,
    COALESCE(pay.`payment_method`, 'CASH') AS `payment_method`,
    IF(s.`prescription_number` IS NOT NULL, 1, 0) AS `is_prescription_dispense`,
    si.`quantity` AS `quantity_sold`,
    si.`unit_price` AS `unit_selling_price`,
    COALESCE(mb.`unit_cost_price`, dp.`standard_retail_price` * 0.50) AS `unit_cost_price`,
    (si.`quantity` * si.`unit_price`) AS `gross_sales_amount`,
    si.`line_discount` AS `discount_amount`,
    si.`tax_amount` AS `tax_amount`,
    (si.`total_line_amount` - si.`line_discount`) AS `net_sales_amount`,
    (si.`quantity` * COALESCE(mb.`unit_cost_price`, dp.`standard_retail_price` * 0.50)) AS `cost_of_goods_sold`,
    ((si.`total_line_amount` - si.`line_discount`) - (si.`quantity` * COALESCE(mb.`unit_cost_price`, dp.`standard_retail_price` * 0.50))) AS `gross_profit`,
    ROUND(
      CASE 
        WHEN (si.`total_line_amount` - si.`line_discount`) > 0 THEN 
          (((si.`total_line_amount` - si.`line_discount`) - (si.`quantity` * COALESCE(mb.`unit_cost_price`, dp.`standard_retail_price` * 0.50))) / (si.`total_line_amount` - si.`line_discount`)) * 100.0
        ELSE 0.00
      END, 2
    ) AS `profit_margin_pct`,
    NOW() AS `etl_loaded_at`
  FROM `pos_retail_db`.`sales` s
  JOIN `pos_retail_db`.`sale_items` si ON s.`sale_id` = si.`sale_id`
  LEFT JOIN `pos_retail_db`.`sale_item_batches` sib ON si.`sale_item_id` = sib.`sale_item_id`
  LEFT JOIN `inventory_procurement_db`.`medicine_batches` mb ON sib.`batch_number` = mb.`batch_number`
  LEFT JOIN `pos_retail_db`.`payments` pay ON s.`sale_id` = pay.`sale_id`
  LEFT JOIN `insurance_claims_db`.`claims` clm ON s.`sale_id` = clm.`pos_sale_id`
  
  -- Surrogate Lookups
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Date` dd 
    ON dd.`date_key` = CAST(DATE_FORMAT(s.`sale_timestamp`, '%Y%m%d') AS UNSIGNED)
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Product` dp 
    ON si.`medicine_id` = dp.`source_medicine_id`
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Customer_Patient` dc 
    ON s.`customer_id` = dc.`source_user_id`
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Supplier` ds 
    ON mb.`supplier_id` = ds.`source_supplier_id`
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Payer` dpay 
    ON clm.`payer_id` = dpay.`source_payer_id`;

  -- ----------------------------------------------------------------------------
  -- STEP 3.6: EXTRACT & LOAD FACT_INVENTORY_BATCHES
  -- Grain: Procured batch inventory status, valuation, near-expiry flags
  -- ----------------------------------------------------------------------------
  TRUNCATE TABLE `central_pharmacy_dwh`.`Fact_Inventory_Batches`;

  INSERT INTO `central_pharmacy_dwh`.`Fact_Inventory_Batches` (
    `received_date_key`,
    `expiry_date_key`,
    `product_key`,
    `supplier_key`,
    `batch_number`,
    `storage_condition`,
    `quality_inspection_status`,
    `initial_quantity`,
    `current_stock_quantity`,
    `dispensed_quantity`,
    `unit_cost_price`,
    `mrp_price`,
    `inventory_cost_valuation`,
    `inventory_retail_valuation`,
    `potential_margin_valuation`,
    `days_until_expiration`,
    `is_expired`,
    `is_near_expiry_90d`,
    `is_near_expiry_30d`,
    `etl_loaded_at`
  )
  SELECT 
    COALESCE(dd_rec.`date_key`, 19000101) AS `received_date_key`,
    COALESCE(dd_exp.`date_key`, 19000101) AS `expiry_date_key`,
    COALESCE(dp.`product_key`, 1) AS `product_key`,
    COALESCE(ds.`supplier_key`, 1) AS `supplier_key`,
    mb.`batch_number`,
    mb.`storage_condition`,
    mb.`quality_inspection_status`,
    mb.`initial_quantity`,
    mb.`current_stock_quantity`,
    (mb.`initial_quantity` - mb.`current_stock_quantity`) AS `dispensed_quantity`,
    mb.`unit_cost_price`,
    mb.`mrp_price`,
    (mb.`current_stock_quantity` * mb.`unit_cost_price`) AS `inventory_cost_valuation`,
    (mb.`current_stock_quantity` * mb.`mrp_price`) AS `inventory_retail_valuation`,
    ((mb.`current_stock_quantity` * mb.`mrp_price`) - (mb.`current_stock_quantity` * mb.`unit_cost_price`)) AS `potential_margin_valuation`,
    DATEDIFF(mb.`expiration_date`, CURDATE()) AS `days_until_expiration`,
    IF(mb.`expiration_date` < CURDATE(), 1, 0) AS `is_expired`,
    IF(mb.`expiration_date` >= CURDATE() AND mb.`expiration_date` <= DATE_ADD(CURDATE(), INTERVAL 90 DAY), 1, 0) AS `is_near_expiry_90d`,
    IF(mb.`expiration_date` >= CURDATE() AND mb.`expiration_date` <= DATE_ADD(CURDATE(), INTERVAL 30 DAY), 1, 0) AS `is_near_expiry_30d`,
    NOW() AS `etl_loaded_at`
  FROM `inventory_procurement_db`.`medicine_batches` mb
  LEFT JOIN `inventory_procurement_db`.`purchase_items` pi 
    ON mb.`batch_number` = pi.`batch_number`
  LEFT JOIN `inventory_procurement_db`.`purchases` p 
    ON pi.`purchase_order_id` = p.`purchase_order_id`
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Date` dd_rec 
    ON dd_rec.`date_key` = CAST(DATE_FORMAT(COALESCE(p.`received_date`, mb.`manufacture_date`), '%Y%m%d') AS UNSIGNED)
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Date` dd_exp 
    ON dd_exp.`date_key` = CAST(DATE_FORMAT(mb.`expiration_date`, '%Y%m%d') AS UNSIGNED)
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Product` dp 
    ON mb.`medicine_id` = dp.`source_medicine_id`
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Supplier` ds 
    ON mb.`supplier_id` = ds.`source_supplier_id`;

  -- ----------------------------------------------------------------------------
  -- STEP 3.7: EXTRACT & LOAD FACT_INSURANCE_CLAIMS
  -- Grain: Claim lifecycle adjudication, copay, and rejection loss
  -- ----------------------------------------------------------------------------
  TRUNCATE TABLE `central_pharmacy_dwh`.`Fact_Insurance_Claims`;

  INSERT INTO `central_pharmacy_dwh`.`Fact_Insurance_Claims` (
    `submission_date_key`,
    `adjudication_date_key`,
    `product_key`,
    `customer_key`,
    `payer_key`,
    `claim_reference_number`,
    `pos_invoice_number`,
    `patient_policy_number`,
    `patient_member_id`,
    `prescription_number`,
    `claim_status`,
    `rejection_code`,
    `rejection_reason`,
    `claim_amount`,
    `copay_amount`,
    `approved_amount`,
    `settlement_amount`,
    `rejection_loss_amount`,
    `turnaround_days`,
    `approval_rate_pct`,
    `etl_loaded_at`
  )
  SELECT 
    COALESCE(dd_sub.`date_key`, 19000101) AS `submission_date_key`,
    COALESCE(dd_adj.`date_key`, 19000101) AS `adjudication_date_key`,
    COALESCE(dp.`product_key`, 1) AS `product_key`,
    COALESCE(dc.`customer_key`, 1) AS `customer_key`,
    COALESCE(dpay.`payer_key`, 1) AS `payer_key`,
    c.`claim_reference_number`,
    s.`invoice_number` AS `pos_invoice_number`,
    c.`patient_policy_number`,
    c.`patient_member_id`,
    c.`prescription_number`,
    c.`claim_status`,
    c.`rejection_code`,
    c.`rejection_reason`,
    c.`claim_amount`,
    c.`copay_amount`,
    c.`approved_amount`,
    c.`settlement_amount`,
    IF(c.`claim_status` = 'REJECTED', c.`claim_amount`, 0.00) AS `rejection_loss_amount`,
    COALESCE(DATEDIFF(c.`adjudication_date`, c.`claim_submission_date`), 0) AS `turnaround_days`,
    IF(c.`claim_status` = 'APPROVED', 100.00, 0.00) AS `approval_rate_pct`,
    NOW() AS `etl_loaded_at`
  FROM `insurance_claims_db`.`claims` c
  JOIN `pos_retail_db`.`sales` s ON c.`pos_sale_id` = s.`sale_id`
  LEFT JOIN (
    SELECT `sale_id`, MIN(`medicine_id`) AS `medicine_id`
    FROM `pos_retail_db`.`sale_items`
    GROUP BY `sale_id`
  ) si ON s.`sale_id` = si.`sale_id`
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Date` dd_sub 
    ON dd_sub.`date_key` = CAST(DATE_FORMAT(c.`claim_submission_date`, '%Y%m%d') AS UNSIGNED)
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Date` dd_adj 
    ON dd_adj.`date_key` = CAST(DATE_FORMAT(c.`adjudication_date`, '%Y%m%d') AS UNSIGNED)
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Product` dp 
    ON si.`medicine_id` = dp.`source_medicine_id`
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Customer_Patient` dc 
    ON s.`customer_id` = dc.`source_user_id`
  LEFT JOIN `central_pharmacy_dwh`.`Dim_Payer` dpay 
    ON c.`payer_id` = dpay.`source_payer_id`;

END$$
DELIMITER ;

-- ------------------------------------------------------------------------------
-- Execute Initial ELT Pipeline Run Immediately
-- ------------------------------------------------------------------------------
CALL `sp_Run_Pharmacy_ELT`();

-- Verification summary counts query
SELECT 'Dim_Product' AS Table_Name, COUNT(*) AS Total_Rows FROM `Dim_Product`
UNION ALL
SELECT 'Dim_Customer_Patient', COUNT(*) FROM `Dim_Customer_Patient`
UNION ALL
SELECT 'Dim_Supplier', COUNT(*) FROM `Dim_Supplier`
UNION ALL
SELECT 'Dim_Payer', COUNT(*) FROM `Dim_Payer`
UNION ALL
SELECT 'Dim_Date', COUNT(*) FROM `Dim_Date`
UNION ALL
SELECT 'Fact_Sales_Transactions', COUNT(*) FROM `Fact_Sales_Transactions`
UNION ALL
SELECT 'Fact_Inventory_Batches', COUNT(*) FROM `Fact_Inventory_Batches`
UNION ALL
SELECT 'Fact_Insurance_Claims', COUNT(*) FROM `Fact_Insurance_Claims`;

-- ==============================================================================
-- End of 03_etl_pipeline.sql
-- ==============================================================================
