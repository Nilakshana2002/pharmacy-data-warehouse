-- ==============================================================================
-- PROJECT: Pharmacy Data Warehouse System (pharmacy-dwh-system)
-- SCRIPT: 01_sources_ddl_and_seed.sql
-- DESCRIPTION: MySQL DDL & Realistic Seed Data for 4 Operational Source Databases:
--   1. pharmacy_core_db         (Master catalog, brands, formulations)
--   2. pos_retail_db            (POS sales, items, batch allocations, payments)
--   3. inventory_procurement_db (Suppliers, batches, purchase orders, stock movements)
--   4. insurance_claims_db      (Payers, claim submissions, copays, adjudications)
-- ==============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- ##############################################################################
-- DATABASE 1: pharmacy_core_db
-- ##############################################################################
CREATE DATABASE IF NOT EXISTS `pharmacy_core_db` 
  DEFAULT CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

USE `pharmacy_core_db`;

DROP TABLE IF EXISTS `medicines`;
DROP TABLE IF EXISTS `medicine_categories`;
DROP TABLE IF EXISTS `brands`;

-- 1. Brands Table
CREATE TABLE `brands` (
  `brand_id` INT AUTO_INCREMENT PRIMARY KEY,
  `brand_name` VARCHAR(100) NOT NULL UNIQUE,
  `manufacturer_country` VARCHAR(50) NOT NULL,
  `contact_email` VARCHAR(100),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Medicine Categories Table
CREATE TABLE `medicine_categories` (
  `category_id` INT AUTO_INCREMENT PRIMARY KEY,
  `category_name` VARCHAR(100) NOT NULL UNIQUE,
  `therapeutic_class` VARCHAR(100) NOT NULL,
  `is_prescription_required` BOOLEAN NOT NULL DEFAULT 0,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 3. Master Medicines Table
CREATE TABLE `medicines` (
  `medicine_id` INT AUTO_INCREMENT PRIMARY KEY,
  `sku_code` VARCHAR(50) NOT NULL UNIQUE,
  `generic_name` VARCHAR(150) NOT NULL,
  `trade_name` VARCHAR(150) NOT NULL,
  `brand_id` INT NOT NULL,
  `category_id` INT NOT NULL,
  `dosage_form` VARCHAR(50) NOT NULL COMMENT 'Tablet, Capsule, Syrup, Inhaler, Injection, Cream',
  `strength` VARCHAR(50) NOT NULL COMMENT 'e.g., 500mg, 20mg, 100mcg/dose',
  `package_size` VARCHAR(50) NOT NULL DEFAULT 'Box of 30',
  `standard_retail_price` DECIMAL(10,2) NOT NULL,
  `reorder_level` INT NOT NULL DEFAULT 50,
  `storage_condition` ENUM('ROOM_TEMP', 'COLD_CHAIN_2_8C', 'CONTROLLED_SUBSTANCE') NOT NULL DEFAULT 'ROOM_TEMP',
  `is_active` BOOLEAN NOT NULL DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_medicines_brand` FOREIGN KEY (`brand_id`) REFERENCES `brands` (`brand_id`),
  CONSTRAINT `fk_medicines_category` FOREIGN KEY (`category_id`) REFERENCES `medicine_categories` (`category_id`)
) ENGINE=InnoDB;

-- ------------------------------------------------------------------------------
-- Seed Data: pharmacy_core_db
-- ------------------------------------------------------------------------------
INSERT INTO `brands` (`brand_id`, `brand_name`, `manufacturer_country`, `contact_email`) VALUES
(1, 'Pfizer Inc.', 'United States', 'supply@pfizer.com'),
(2, 'Novartis AG', 'Switzerland', 'distribution@novartis.com'),
(3, 'GlaxoSmithKline (GSK)', 'United Kingdom', 'logistics@gsk.com'),
(4, 'Sanofi S.A.', 'France', 'orders@sanofi.com'),
(5, 'AstraZeneca PLC', 'United Kingdom', 'supply-chain@astrazeneca.com'),
(6, 'Sun Pharmaceutical Industries', 'India', 'exports@sunpharma.com'),
(7, 'Cipla Ltd.', 'India', 'contact@cipla.com'),
(8, 'Bayer AG', 'Germany', 'pharma@bayer.com'),
(9, 'Abbott Laboratories', 'United States', 'rxsales@abbott.com'),
(10, 'Merck Sharp & Dohme (MSD)', 'United States', 'globalrx@merck.com');

INSERT INTO `medicine_categories` (`category_id`, `category_name`, `therapeutic_class`, `is_prescription_required`) VALUES
(1, 'Antibiotics & Anti-infectives', 'Anti-Infectives', 1),
(2, 'Cardiovascular & Statins', 'Cardiovascular System', 1),
(3, 'Diabetes Care & Endocrinology', 'Endocrine & Metabolic', 1),
(4, 'Analgesics & Pain Management', 'Central Nervous System', 0),
(5, 'Respiratory & Asthma', 'Respiratory System', 1),
(6, 'Gastrointestinal & Antacids', 'Alimentary Tract', 0),
(7, 'Antihistamines & Allergy', 'Respiratory System', 0),
(8, 'Antihypertensives & Beta-Blockers', 'Cardiovascular System', 1),
(9, 'Psychotropics & Neurological', 'Central Nervous System', 1),
(10, 'Dermatologicals & Topicals', 'Dermatology', 0);

INSERT INTO `medicines` (`medicine_id`, `sku_code`, `generic_name`, `trade_name`, `brand_id`, `category_id`, `dosage_form`, `strength`, `package_size`, `standard_retail_price`, `reorder_level`, `storage_condition`, `is_active`) VALUES
(1, 'MED-AMOX-500', 'Amoxicillin Trihydrate', 'Amoxil Forte', 3, 1, 'Capsule', '500mg', 'Strip of 20', 14.50, 100, 'ROOM_TEMP', 1),
(2, 'MED-ATOR-020', 'Atorvastatin Calcium', 'Lipitor Care', 1, 2, 'Tablet', '20mg', 'Box of 30', 42.00, 80, 'ROOM_TEMP', 1),
(3, 'MED-METF-850', 'Metformin Hydrochloride', 'Glucophage Retard', 4, 3, 'Tablet', '850mg', 'Box of 60', 18.25, 120, 'ROOM_TEMP', 1),
(4, 'MED-PARA-500', 'Paracetamol / Acetaminophen', 'Panadol Extra', 3, 4, 'Tablet', '500mg', 'Blister of 24', 6.50, 200, 'ROOM_TEMP', 1),
(5, 'MED-IBUP-400', 'Ibuprofen', 'Advil Max Relief', 1, 4, 'Tablet', '400mg', 'Box of 30', 9.75, 150, 'ROOM_TEMP', 1),
(6, 'MED-OMEP-020', 'Omeprazole Magnesium', 'Prilosec Protect', 5, 6, 'Capsule', '20mg', 'Bottle of 28', 21.00, 70, 'ROOM_TEMP', 1),
(7, 'MED-CETI-010', 'Cetirizine Hydrochloride', 'Zyrtec Relief', 9, 7, 'Tablet', '10mg', 'Blister of 30', 12.00, 90, 'ROOM_TEMP', 1),
(8, 'MED-SALB-100', 'Salbutamol Sulfate', 'Ventolin Evohaler', 3, 5, 'Inhaler', '100mcg/actuation', '200 Doses', 28.50, 60, 'ROOM_TEMP', 1),
(9, 'MED-LOSA-050', 'Losartan Potassium', 'Cozaar Balance', 10, 8, 'Tablet', '50mg', 'Box of 30', 31.50, 75, 'ROOM_TEMP', 1),
(10, 'MED-AZIT-500', 'Azithromycin Monohydrate', 'Zithromax Tri-Pak', 1, 1, 'Tablet', '500mg', 'Pack of 3', 25.00, 50, 'ROOM_TEMP', 1),
(11, 'MED-INSU-100', 'Insulin Glargine', 'Lantus SoloStar', 4, 3, 'Injection', '100 units/mL', '5 x 3mL Pens', 115.00, 40, 'COLD_CHAIN_2_8C', 1),
(12, 'MED-CIPR-500', 'Ciprofloxacin HCl', 'Ciproxin Pro', 8, 1, 'Tablet', '500mg', 'Box of 14', 19.80, 50, 'ROOM_TEMP', 1),
(13, 'MED-PANT-040', 'Pantoprazole Sodium', 'Protium Gastro', 2, 6, 'Tablet', '40mg', 'Box of 28', 24.50, 60, 'ROOM_TEMP', 1),
(14, 'MED-ESCI-010', 'Escitalopram Oxalate', 'Lexapro Zen', 9, 9, 'Tablet', '10mg', 'Box of 28', 38.00, 45, 'ROOM_TEMP', 1),
(15, 'MED-ROSU-010', 'Rosuvastatin Calcium', 'Crestor Cardio', 5, 2, 'Tablet', '10mg', 'Box of 30', 48.00, 65, 'ROOM_TEMP', 1),
(16, 'MED-DOXY-100', 'Doxycycline Hyclate', 'Vibramycin D', 1, 1, 'Capsule', '100mg', 'Pack of 10', 16.20, 55, 'ROOM_TEMP', 1),
(17, 'MED-MONT-010', 'Montelukast Sodium', 'Singulair Breath', 10, 5, 'Tablet', '10mg', 'Box of 28', 34.00, 60, 'ROOM_TEMP', 1),
(18, 'MED-AUGM-625', 'Amoxicillin / Clavulanic Acid', 'Augmentin Duo', 3, 1, 'Tablet', '625mg', 'Pack of 14', 27.50, 85, 'ROOM_TEMP', 1),
(19, 'MED-GLIM-002', 'Glimepiride', 'Amaryl Metabolic', 4, 3, 'Tablet', '2mg', 'Box of 30', 15.00, 60, 'ROOM_TEMP', 1),
(20, 'MED-CLOP-075', 'Clopidogrel Bisulfate', 'Plavix Thromb', 4, 2, 'Tablet', '75mg', 'Box of 28', 44.50, 70, 'ROOM_TEMP', 1);


-- ##############################################################################
-- DATABASE 2: inventory_procurement_db
-- ##############################################################################
CREATE DATABASE IF NOT EXISTS `inventory_procurement_db` 
  DEFAULT CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

USE `inventory_procurement_db`;

DROP TABLE IF EXISTS `stock_movements`;
DROP TABLE IF EXISTS `purchase_items`;
DROP TABLE IF EXISTS `purchases`;
DROP TABLE IF EXISTS `medicine_batches`;
DROP TABLE IF EXISTS `suppliers`;

-- 1. Suppliers Table
CREATE TABLE `suppliers` (
  `supplier_id` INT AUTO_INCREMENT PRIMARY KEY,
  `supplier_name` VARCHAR(120) NOT NULL,
  `license_number` VARCHAR(60) NOT NULL UNIQUE,
  `contact_person` VARCHAR(100),
  `email` VARCHAR(100),
  `phone` VARCHAR(30),
  `address` VARCHAR(200),
  `city` VARCHAR(60),
  `country` VARCHAR(60),
  `payment_terms_days` INT DEFAULT 30,
  `is_active` BOOLEAN DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Medicine Batches Table (Procured Inventory Units)
CREATE TABLE `medicine_batches` (
  `batch_id` INT AUTO_INCREMENT PRIMARY KEY,
  `batch_number` VARCHAR(50) NOT NULL UNIQUE,
  `medicine_id` INT NOT NULL COMMENT 'Logical reference to pharmacy_core_db.medicines.medicine_id',
  `supplier_id` INT NOT NULL,
  `manufacture_date` DATE NOT NULL,
  `expiration_date` DATE NOT NULL,
  `initial_quantity` INT NOT NULL,
  `current_stock_quantity` INT NOT NULL,
  `unit_cost_price` DECIMAL(10,2) NOT NULL,
  `mrp_price` DECIMAL(10,2) NOT NULL,
  `storage_condition` ENUM('ROOM_TEMP', 'COLD_CHAIN_2_8C', 'CONTROLLED_SUBSTANCE') DEFAULT 'ROOM_TEMP',
  `quality_inspection_status` ENUM('PASSED', 'QUARANTINED', 'REJECTED') DEFAULT 'PASSED',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_batch_supplier` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`supplier_id`),
  INDEX `idx_batch_exp` (`expiration_date`),
  INDEX `idx_batch_med` (`medicine_id`)
) ENGINE=InnoDB;

-- 3. Purchases (PO Header)
CREATE TABLE `purchases` (
  `purchase_order_id` INT AUTO_INCREMENT PRIMARY KEY,
  `po_number` VARCHAR(50) NOT NULL UNIQUE,
  `supplier_id` INT NOT NULL,
  `order_date` DATE NOT NULL,
  `expected_delivery_date` DATE NOT NULL,
  `received_date` DATE,
  `total_cost` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `purchase_status` ENUM('ORDERED', 'RECEIVED', 'PARTIALLY_RECEIVED', 'CANCELLED') DEFAULT 'RECEIVED',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_purchases_supplier` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`supplier_id`)
) ENGINE=InnoDB;

-- 4. Purchase Items (PO Lines)
CREATE TABLE `purchase_items` (
  `purchase_item_id` INT AUTO_INCREMENT PRIMARY KEY,
  `purchase_order_id` INT NOT NULL,
  `medicine_id` INT NOT NULL,
  `batch_number` VARCHAR(50) NOT NULL,
  `ordered_qty` INT NOT NULL,
  `received_qty` INT NOT NULL,
  `unit_cost_price` DECIMAL(10,2) NOT NULL,
  `total_cost` DECIMAL(12,2) NOT NULL,
  CONSTRAINT `fk_po_items_header` FOREIGN KEY (`purchase_order_id`) REFERENCES `purchases` (`purchase_order_id`),
  INDEX `idx_po_items_batch` (`batch_number`)
) ENGINE=InnoDB;

-- 5. Stock Movements (Inventory Ledger)
CREATE TABLE `stock_movements` (
  `movement_id` INT AUTO_INCREMENT PRIMARY KEY,
  `batch_id` INT NOT NULL,
  `movement_type` ENUM('RECEIPT', 'SALE_DISPENSE', 'DAMAGED_WRITE_OFF', 'EXPIRED_DISPOSAL', 'AUDIT_ADJUSTMENT') NOT NULL,
  `quantity_change` INT NOT NULL COMMENT 'Positive for stock-in, negative for stock-out',
  `reference_doc_type` VARCHAR(50) COMMENT 'PURCHASE_ORDER, POS_SALE, WRITE_OFF_AUDIT',
  `reference_doc_id` VARCHAR(50),
  `movement_timestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `notes` VARCHAR(255),
  CONSTRAINT `fk_movements_batch` FOREIGN KEY (`batch_id`) REFERENCES `medicine_batches` (`batch_id`)
) ENGINE=InnoDB;

-- ------------------------------------------------------------------------------
-- Seed Data: inventory_procurement_db
-- ------------------------------------------------------------------------------
INSERT INTO `suppliers` (`supplier_id`, `supplier_name`, `license_number`, `contact_person`, `email`, `phone`, `address`, `city`, `country`, `payment_terms_days`) VALUES
(1, 'Amerisource Health Logistics', 'WHL-USA-2021-9941', 'Daniel Vance', 'orders@amerisource-hl.com', '+1-800-555-0191', '100 Logistics Blvd', 'Chesterbrook', 'United States', 45),
(2, 'EuroPharm Distribution NV', 'WHL-EUR-2019-3382', 'Monique Dubois', 'supply@europharm.be', '+32-2-555-8821', 'Avenue Louise 450', 'Brussels', 'Belgium', 30),
(3, 'Pan-Asia Healthcare Wholesale', 'WHL-IND-2022-7714', 'Rajesh Sharma', 'export@panasiahealth.in', '+91-22-2847-9000', 'BKC Kurla East', 'Mumbai', 'India', 30),
(4, 'Cardinal Direct MedSupply', 'WHL-USA-2020-5529', 'Rachel Adams', 'direct@cardinal-med.com', '+1-800-555-0422', '7000 Cardinal Way', 'Dublin', 'United States', 60),
(5, 'Nordic Pharma Logistics ApS', 'WHL-DNK-2023-1108', 'Lars Mikkelsen', 'nordic@pharmalogistics.dk', '+45-33-12-99-40', 'Islands Brygge 12', 'Copenhagen', 'Denmark', 30);

-- Batches across medicines (incorporating fresh, near-expiry, and expired dates relative to 2026-10-20)
INSERT INTO `medicine_batches` (`batch_id`, `batch_number`, `medicine_id`, `supplier_id`, `manufacture_date`, `expiration_date`, `initial_quantity`, `current_stock_quantity`, `unit_cost_price`, `mrp_price`, `storage_condition`, `quality_inspection_status`) VALUES
(1,  'BAT-AMX-2025-01', 1,  1, '2025-01-10', '2026-11-15', 500, 68,   7.50, 14.50, 'ROOM_TEMP', 'PASSED'),     -- Near expiry (~25 days)
(2,  'BAT-AMX-2026-02', 1,  3, '2026-03-01', '2027-08-30', 800, 620,  7.10, 14.50, 'ROOM_TEMP', 'PASSED'),     -- Good
(3,  'BAT-ATR-2025-A1', 2,  1, '2025-02-15', '2026-11-20', 400, 45,  22.00, 42.00, 'ROOM_TEMP', 'PASSED'),     -- Near expiry (~30 days)
(4,  'BAT-ATR-2026-B2', 2,  4, '2026-04-10', '2028-04-10', 600, 480, 21.00, 42.00, 'ROOM_TEMP', 'PASSED'),     -- Good
(5,  'BAT-MET-2024-99', 3,  2, '2024-09-01', '2026-09-01', 600, 0,    8.50, 18.25, 'ROOM_TEMP', 'PASSED'),     -- Expired
(6,  'BAT-MET-2026-01', 3,  3, '2026-01-15', '2027-12-31', 900, 710,  8.00, 18.25, 'ROOM_TEMP', 'PASSED'),     -- Good
(7,  'BAT-PAR-2025-88', 4,  3, '2025-03-01', '2027-03-01', 1500, 940, 2.80,  6.50, 'ROOM_TEMP', 'PASSED'),     -- Good
(8,  'BAT-IBU-2025-44', 5,  1, '2025-04-12', '2026-12-05', 800, 92,   4.20,  9.75, 'ROOM_TEMP', 'PASSED'),     -- Near expiry (~45 days)
(9,  'BAT-OME-2025-02', 6,  2, '2025-05-20', '2027-05-20', 500, 310,  9.80, 21.00, 'ROOM_TEMP', 'PASSED'),     -- Good
(10, 'BAT-CET-2025-11', 7,  3, '2025-06-15', '2027-06-15', 700, 490,  5.00, 12.00, 'ROOM_TEMP', 'PASSED'),     -- Good
(11, 'BAT-SAL-2025-07', 8,  1, '2025-07-01', '2026-11-05', 400, 32,  14.00, 28.50, 'ROOM_TEMP', 'PASSED'),     -- Critical near expiry (16 days!)
(12, 'BAT-SAL-2026-08', 8,  4, '2026-05-10', '2028-05-10', 500, 430, 13.50, 28.50, 'ROOM_TEMP', 'PASSED'),     -- Good
(13, 'BAT-LOS-2025-03', 9,  2, '2025-03-10', '2027-03-10', 550, 380, 15.00, 31.50, 'ROOM_TEMP', 'PASSED'),     -- Good
(14, 'BAT-AZI-2025-09', 10, 1, '2025-08-01', '2026-12-18', 350, 48,  12.00, 25.00, 'ROOM_TEMP', 'PASSED'),     -- Near expiry (~60 days)
(15, 'BAT-INS-2026-01', 11, 2, '2026-01-20', '2027-01-20', 250, 160, 68.00, 115.00, 'COLD_CHAIN_2_8C', 'PASSED'),-- Cold chain
(16, 'BAT-CIP-2025-05', 12, 5, '2025-05-01', '2027-05-01', 400, 275,  8.50, 19.80, 'ROOM_TEMP', 'PASSED'),     -- Good
(17, 'BAT-PAN-2025-12', 13, 2, '2025-09-10', '2027-09-10', 450, 330, 11.20, 24.50, 'ROOM_TEMP', 'PASSED'),     -- Good
(18, 'BAT-ESC-2025-22', 14, 4, '2025-06-25', '2027-06-25', 300, 195, 18.00, 38.00, 'ROOM_TEMP', 'PASSED'),     -- Good
(19, 'BAT-ROS-2026-04', 15, 1, '2026-02-14', '2028-02-14', 400, 315, 24.00, 48.00, 'ROOM_TEMP', 'PASSED'),     -- Good
(20, 'BAT-AUG-2025-17', 18, 3, '2025-04-18', '2026-11-28', 500, 52,  13.50, 27.50, 'ROOM_TEMP', 'PASSED');     -- Near expiry (~38 days)

INSERT INTO `purchases` (`purchase_order_id`, `po_number`, `supplier_id`, `order_date`, `expected_delivery_date`, `received_date`, `total_cost`, `purchase_status`) VALUES
(1, 'PO-2025-00101', 1, '2025-01-02', '2025-01-08', '2025-01-09', 3750.00, 'RECEIVED'),
(2, 'PO-2025-00204', 1, '2025-02-05', '2025-02-12', '2025-02-14', 8800.00, 'RECEIVED'),
(3, 'PO-2025-00312', 3, '2025-02-20', '2025-02-28', '2025-03-01', 4200.00, 'RECEIVED'),
(4, 'PO-2026-00440', 2, '2026-01-08', '2026-01-18', '2026-01-19', 17000.00, 'RECEIVED'),
(5, 'PO-2026-00515', 4, '2026-03-25', '2026-04-05', '2026-04-08', 12600.00, 'RECEIVED');

INSERT INTO `purchase_items` (`purchase_item_id`, `purchase_order_id`, `medicine_id`, `batch_number`, `ordered_qty`, `received_qty`, `unit_cost_price`, `total_cost`) VALUES
(1, 1, 1,  'BAT-AMX-2025-01', 500, 500,  7.50,  3750.00),
(2, 2, 2,  'BAT-ATR-2025-A1', 400, 400, 22.00,  8800.00),
(3, 3, 4,  'BAT-PAR-2025-88', 1500, 1500, 2.80, 4200.00),
(4, 4, 11, 'BAT-INS-2026-01', 250, 250, 68.00, 17000.00),
(5, 5, 2,  'BAT-ATR-2026-B2', 600, 600, 21.00, 12600.00);

INSERT INTO `stock_movements` (`batch_id`, `movement_type`, `quantity_change`, `reference_doc_type`, `reference_doc_id`, `movement_timestamp`, `notes`) VALUES
(1, 'RECEIPT', 500, 'PURCHASE_ORDER', 'PO-2025-00101', '2025-01-09 10:15:00', 'Initial batch intake passed QC'),
(2, 'RECEIPT', 800, 'PURCHASE_ORDER', 'PO-2026-00515', '2026-03-02 09:30:00', 'Bulk restock intake'),
(5, 'EXPIRED_DISPOSAL', -25, 'WRITE_OFF_AUDIT', 'WO-2026-091', '2026-09-05 14:00:00', 'Disposal of expired units past Sep 2026'),
(11, 'DAMAGED_WRITE_OFF', -5, 'WRITE_OFF_AUDIT', 'WO-2026-104', '2026-08-12 11:20:00', 'Inhaler actuator damage during shelf display');


-- ##############################################################################
-- DATABASE 3: pos_retail_db
-- ##############################################################################
CREATE DATABASE IF NOT EXISTS `pos_retail_db` 
  DEFAULT CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

USE `pos_retail_db`;

DROP TABLE IF EXISTS `payments`;
DROP TABLE IF EXISTS `sale_item_batches`;
DROP TABLE IF EXISTS `sale_items`;
DROP TABLE IF EXISTS `sales`;
DROP TABLE IF EXISTS `users`;

-- 1. Users Table (Patients, Customers, Pharmacy Staff)
CREATE TABLE `users` (
  `user_id` INT AUTO_INCREMENT PRIMARY KEY,
  `full_name` VARCHAR(120) NOT NULL,
  `email` VARCHAR(100),
  `phone_number` VARCHAR(30) NOT NULL,
  `date_of_birth` DATE,
  `gender` ENUM('MALE', 'FEMALE', 'OTHER') NOT NULL,
  `address` VARCHAR(255),
  `city` VARCHAR(80) DEFAULT 'Metropolis',
  `user_type` ENUM('PATIENT_CUSTOMER', 'PHARMACIST', 'CASHIER') NOT NULL DEFAULT 'PATIENT_CUSTOMER',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Sales Header (Receipts)
CREATE TABLE `sales` (
  `sale_id` INT AUTO_INCREMENT PRIMARY KEY,
  `invoice_number` VARCHAR(50) NOT NULL UNIQUE,
  `customer_id` INT NOT NULL,
  `cashier_id` INT NOT NULL,
  `prescription_number` VARCHAR(50) NULL COMMENT 'NULL for Over-The-Counter sales',
  `doctor_name` VARCHAR(120) NULL COMMENT 'Doctor reference if Rx sale',
  `sale_timestamp` DATETIME NOT NULL,
  `subtotal_amount` DECIMAL(12,2) NOT NULL,
  `discount_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `tax_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `total_amount` DECIMAL(12,2) NOT NULL,
  `sale_channel` ENUM('COUNTER_WALK_IN', 'ONLINE_PICKUP', 'HOME_DELIVERY') DEFAULT 'COUNTER_WALK_IN',
  `status` ENUM('COMPLETED', 'REFUNDED', 'CANCELLED') DEFAULT 'COMPLETED',
  CONSTRAINT `fk_sales_customer` FOREIGN KEY (`customer_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_sales_cashier` FOREIGN KEY (`cashier_id`) REFERENCES `users` (`user_id`),
  INDEX `idx_sales_ts` (`sale_timestamp`),
  INDEX `idx_sales_rx` (`prescription_number`)
) ENGINE=InnoDB;

-- 3. Sale Items Table
CREATE TABLE `sale_items` (
  `sale_item_id` INT AUTO_INCREMENT PRIMARY KEY,
  `sale_id` INT NOT NULL,
  `medicine_id` INT NOT NULL COMMENT 'Logical reference to pharmacy_core_db.medicines.medicine_id',
  `quantity` INT NOT NULL,
  `unit_price` DECIMAL(10,2) NOT NULL,
  `line_discount` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `tax_amount` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `total_line_amount` DECIMAL(12,2) NOT NULL,
  CONSTRAINT `fk_items_sale` FOREIGN KEY (`sale_id`) REFERENCES `sales` (`sale_id`),
  INDEX `idx_sale_items_med` (`medicine_id`)
) ENGINE=InnoDB;

-- 4. Sale Item Batches Table (POS Lot Allocation for FIFO & Traceability)
CREATE TABLE `sale_item_batches` (
  `allocation_id` INT AUTO_INCREMENT PRIMARY KEY,
  `sale_item_id` INT NOT NULL,
  `batch_number` VARCHAR(50) NOT NULL COMMENT 'Matches inventory_procurement_db.medicine_batches.batch_number',
  `quantity_dispensed` INT NOT NULL,
  `batch_expiry_date` DATE NOT NULL,
  CONSTRAINT `fk_alloc_sale_item` FOREIGN KEY (`sale_item_id`) REFERENCES `sale_items` (`sale_item_id`)
) ENGINE=InnoDB;

-- 5. Payments Table
CREATE TABLE `payments` (
  `payment_id` INT AUTO_INCREMENT PRIMARY KEY,
  `sale_id` INT NOT NULL,
  `payment_method` ENUM('CASH', 'CREDIT_CARD', 'DEBIT_CARD', 'INSURANCE_DIRECT', 'DIGITAL_WALLET') NOT NULL,
  `amount_paid` DECIMAL(12,2) NOT NULL,
  `transaction_reference` VARCHAR(100),
  `payment_status` ENUM('SUCCESS', 'FAILED', 'PENDING') DEFAULT 'SUCCESS',
  `payment_time` DATETIME DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_payments_sale` FOREIGN KEY (`sale_id`) REFERENCES `sales` (`sale_id`)
) ENGINE=InnoDB;

-- ------------------------------------------------------------------------------
-- Seed Data: pos_retail_db
-- ------------------------------------------------------------------------------
INSERT INTO `users` (`user_id`, `full_name`, `email`, `phone_number`, `date_of_birth`, `gender`, `address`, `city`, `user_type`) VALUES
(1,  'Dr. Sarah Lin (Lead Pharmacist)', 'sarah.lin@pharmacycorp.com', '+1-555-0101', '1984-06-12', 'FEMALE', 'Staff Station A', 'Metropolis', 'PHARMACIST'),
(2,  'Mark Jenkins (Cashier)',          'mark.j@pharmacycorp.com',    '+1-555-0102', '1996-03-22', 'MALE',   'Counter Register 1', 'Metropolis', 'CASHIER'),
(3,  'James Henderson',                 'james.henderson@email.com',  '+1-555-8831', '1962-04-15', 'MALE',   '742 Evergreen Terrace', 'Metropolis', 'PATIENT_CUSTOMER'),
(4,  'Eleanor Vance',                   'eleanor.v@email.com',        '+1-555-4921', '1954-11-03', 'FEMALE', '12 Oak Ridge Rd', 'Metropolis', 'PATIENT_CUSTOMER'),
(5,  'Marcus Brody',                    'marcus.b@email.com',         '+1-555-1234', '1988-08-27', 'MALE',   '89 Elm Street Apt 4B', 'Metropolis', 'PATIENT_CUSTOMER'),
(6,  'Clara Oswald',                    'clara.oswald@email.com',     '+1-555-5544', '1992-12-14', 'FEMALE', '221B Baker St Suburb', 'Metropolis', 'PATIENT_CUSTOMER'),
(7,  'Thomas Wayne',                    'twayne@medicarecare.net',    '+1-555-9090', '1948-02-19', 'MALE',   '100 Gotham Heights', 'Metropolis', 'PATIENT_CUSTOMER'),
(8,  'Aria Montgomery',                 'aria.m@email.com',           '+1-555-6712', '2001-07-09', 'FEMALE', '45 Pine Valley', 'Metropolis', 'PATIENT_CUSTOMER'),
(9,  'Lucas Scott',                     'lscott@email.com',           '+1-555-3321', '1979-05-30', 'MALE',   '33 River Walk', 'Metropolis', 'PATIENT_CUSTOMER'),
(10, 'Sophia Rodriguez',                'sophia.r@email.com',         '+1-555-4499', '1971-10-05', 'FEMALE', '512 Sunset Blvd', 'Metropolis', 'PATIENT_CUSTOMER');

-- Sales across multiple dates in 2026 (Mixed OTC & Doctor Rx)
INSERT INTO `sales` (`sale_id`, `invoice_number`, `customer_id`, `cashier_id`, `prescription_number`, `doctor_name`, `sale_timestamp`, `subtotal_amount`, `discount_amount`, `tax_amount`, `total_amount`, `sale_channel`, `status`) VALUES
(1,  'INV-2026-0801', 3, 2, 'RX-2026-9041', 'Dr. Arthur Miller, MD',     '2026-08-05 10:14:22', 84.00, 0.00, 4.20, 88.20, 'COUNTER_WALK_IN', 'COMPLETED'),
(2,  'INV-2026-0802', 4, 2, 'RX-2026-9042', 'Dr. Elena Rostova, MD',     '2026-08-12 11:30:10', 115.00, 5.00, 5.50, 115.50, 'COUNTER_WALK_IN', 'COMPLETED'),
(3,  'INV-2026-0803', 5, 2, NULL,           NULL,                        '2026-08-18 14:05:40', 16.25, 0.00, 0.81, 17.06, 'COUNTER_WALK_IN', 'COMPLETED'), -- OTC
(4,  'INV-2026-0804', 6, 2, NULL,           NULL,                        '2026-08-25 16:45:12', 30.75, 2.00, 1.44, 30.19, 'COUNTER_WALK_IN', 'COMPLETED'), -- OTC
(5,  'INV-2026-0901', 7, 2, 'RX-2026-9104', 'Dr. Marcus Thorne, MD',    '2026-09-02 09:22:15', 73.50, 0.00, 3.68, 77.18, 'COUNTER_WALK_IN', 'COMPLETED'),
(6,  'INV-2026-0902', 8, 2, 'RX-2026-9115', 'Dr. Chloe Bennett, MD',     '2026-09-10 15:10:00', 50.00, 0.00, 2.50, 52.50, 'HOME_DELIVERY',   'COMPLETED'),
(7,  'INV-2026-0903', 9, 2, 'RX-2026-9122', 'Dr. Arthur Miller, MD',     '2026-09-19 12:40:35', 57.00, 3.00, 2.70, 56.70, 'COUNTER_WALK_IN', 'COMPLETED'),
(8,  'INV-2026-0904', 10, 2, 'RX-2026-9130', 'Dr. Elena Rostova, MD',    '2026-09-28 17:05:50', 126.00, 10.00, 5.80, 121.80, 'ONLINE_PICKUP', 'COMPLETED'),
(9,  'INV-2026-1001', 3, 2, 'RX-2026-9201', 'Dr. Arthur Miller, MD',     '2026-10-02 10:50:11', 42.00, 0.00, 2.10, 44.10, 'COUNTER_WALK_IN', 'COMPLETED'),
(10, 'INV-2026-1002', 4, 2, 'RX-2026-9214', 'Dr. Elena Rostova, MD',     '2026-10-08 14:15:20', 230.00, 15.00, 10.75, 225.75, 'COUNTER_WALK_IN', 'COMPLETED'),
(11, 'INV-2026-1003', 5, 2, NULL,           NULL,                        '2026-10-12 18:22:45', 21.75, 0.00, 1.09, 22.84, 'COUNTER_WALK_IN', 'COMPLETED'), -- OTC
(12, 'INV-2026-1004', 6, 2, 'RX-2026-9229', 'Dr. Marcus Thorne, MD',    '2026-10-15 11:05:00', 28.50, 0.00, 1.43, 29.93, 'COUNTER_WALK_IN', 'COMPLETED');

-- Sale Items
INSERT INTO `sale_items` (`sale_item_id`, `sale_id`, `medicine_id`, `quantity`, `unit_price`, `line_discount`, `tax_amount`, `total_line_amount`) VALUES
(1,  1,  2, 2, 42.00, 0.00, 4.20, 84.00),   -- Atorvastatin 20mg (2 packs)
(2,  2,  11, 1, 115.00, 5.00, 5.50, 110.00), -- Lantus Insulin
(3,  3,  4, 1, 6.50, 0.00, 0.33, 6.50),     -- Paracetamol OTC
(4,  3,  5, 1, 9.75, 0.00, 0.48, 9.75),     -- Ibuprofen OTC
(5,  4,  5, 2, 9.75, 2.00, 0.88, 17.50),    -- Ibuprofen OTC
(6,  4,  7, 1, 12.00, 0.00, 0.60, 12.00),   -- Cetirizine OTC
(7,  5,  9, 1, 31.50, 0.00, 1.58, 31.50),   -- Losartan
(8,  5,  2, 1, 42.00, 0.00, 2.10, 42.00),   -- Atorvastatin
(9,  6,  10, 2, 25.00, 0.00, 2.50, 50.00),  -- Azithromycin
(10, 7,  8, 2, 28.50, 3.00, 2.70, 54.00),   -- Ventolin Inhaler
(11, 8,  15, 2, 48.00, 5.00, 4.55, 91.00),  -- Rosuvastatin
(12, 8,  3, 2, 18.25, 5.00, 1.58, 31.50),   -- Metformin
(13, 9,  2, 1, 42.00, 0.00, 2.10, 42.00),   -- Atorvastatin
(14, 10, 11, 2, 115.00, 15.00, 10.75, 215.00), -- Lantus Insulin
(15, 11, 4, 2, 6.50, 0.00, 0.65, 13.00),    -- Paracetamol OTC
(16, 11, 5, 1, 9.75, 0.00, 0.49, 9.75),     -- Ibuprofen OTC
(17, 12, 8, 1, 28.50, 0.00, 1.43, 28.50);   -- Ventolin Inhaler

-- Batches dispensed at POS counter
INSERT INTO `sale_item_batches` (`sale_item_id`, `batch_number`, `quantity_dispensed`, `batch_expiry_date`) VALUES
(1,  'BAT-ATR-2025-A1', 2, '2026-11-20'),
(2,  'BAT-INS-2026-01', 1, '2027-01-20'),
(3,  'BAT-PAR-2025-88', 1, '2027-03-01'),
(4,  'BAT-IBU-2025-44', 1, '2026-12-05'),
(5,  'BAT-IBU-2025-44', 2, '2026-12-05'),
(6,  'BAT-CET-2025-11', 1, '2027-06-15'),
(7,  'BAT-LOS-2025-03', 1, '2027-03-10'),
(8,  'BAT-ATR-2025-A1', 1, '2026-11-20'),
(9,  'BAT-AZI-2025-09', 2, '2026-12-18'),
(10, 'BAT-SAL-2025-07', 2, '2026-11-05'),
(11, 'BAT-ROS-2026-04', 2, '2028-02-14'),
(12, 'BAT-MET-2026-01', 2, '2027-12-31'),
(13, 'BAT-ATR-2026-B2', 1, '2028-04-10'),
(14, 'BAT-INS-2026-01', 2, '2027-01-20'),
(15, 'BAT-PAR-2025-88', 2, '2027-03-01'),
(16, 'BAT-IBU-2025-44', 1, '2026-12-05'),
(17, 'BAT-SAL-2025-07', 1, '2026-11-05');

-- Payments
INSERT INTO `payments` (`sale_id`, `payment_method`, `amount_paid`, `transaction_reference`, `payment_status`, `payment_time`) VALUES
(1,  'INSURANCE_DIRECT', 88.20,  'TXN-INS-80419', 'SUCCESS', '2026-08-05 10:15:00'),
(2,  'INSURANCE_DIRECT', 115.50, 'TXN-INS-80425', 'SUCCESS', '2026-08-12 11:32:00'),
(3,  'CASH',             17.06,  'TXN-CSH-00192', 'SUCCESS', '2026-08-18 14:06:00'),
(4,  'CREDIT_CARD',      30.19,  'TXN-CC-771829', 'SUCCESS', '2026-08-25 16:46:00'),
(5,  'INSURANCE_DIRECT', 77.18,  'TXN-INS-91040', 'SUCCESS', '2026-09-02 09:24:00'),
(6,  'DIGITAL_WALLET',   52.50,  'TXN-WLT-99210', 'SUCCESS', '2026-09-10 15:11:00'),
(7,  'CREDIT_CARD',      56.70,  'TXN-CC-882190', 'SUCCESS', '2026-09-19 12:42:00'),
(8,  'INSURANCE_DIRECT', 121.80, 'TXN-INS-91302', 'SUCCESS', '2026-09-28 17:07:00'),
(9,  'INSURANCE_DIRECT', 44.10,  'TXN-INS-92015', 'SUCCESS', '2026-10-02 10:52:00'),
(10, 'INSURANCE_DIRECT', 225.75, 'TXN-INS-92144', 'SUCCESS', '2026-10-08 14:18:00'),
(11, 'CASH',             22.84,  'TXN-CSH-00445', 'SUCCESS', '2026-10-12 18:24:00'),
(12, 'DEBIT_CARD',       29.93,  'TXN-DC-109244', 'SUCCESS', '2026-10-15 11:06:00');


-- ##############################################################################
-- DATABASE 4: insurance_claims_db
-- ##############################################################################
CREATE DATABASE IF NOT EXISTS `insurance_claims_db` 
  DEFAULT CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

USE `insurance_claims_db`;

DROP TABLE IF EXISTS `claims`;
DROP TABLE IF EXISTS `payers`;

-- 1. Insurance Payers Table
CREATE TABLE `payers` (
  `payer_id` INT AUTO_INCREMENT PRIMARY KEY,
  `payer_code` VARCHAR(30) NOT NULL UNIQUE,
  `payer_name` VARCHAR(120) NOT NULL,
  `payer_type` ENUM('GOVERNMENT', 'COMMERCIAL_HMO', 'PRIVATE_PPO', 'EMPLOYER_SPONSORED') NOT NULL,
  `contact_email` VARCHAR(100),
  `phone` VARCHAR(30),
  `edi_claim_endpoint` VARCHAR(255),
  `average_turnaround_days` INT DEFAULT 14,
  `is_active` BOOLEAN DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Claims Table
CREATE TABLE `claims` (
  `claim_id` INT AUTO_INCREMENT PRIMARY KEY,
  `claim_reference_number` VARCHAR(60) NOT NULL UNIQUE,
  `pos_sale_id` INT NOT NULL COMMENT 'Reference to pos_retail_db.sales.sale_id',
  `payer_id` INT NOT NULL,
  `patient_policy_number` VARCHAR(50) NOT NULL,
  `patient_member_id` VARCHAR(50) NOT NULL,
  `prescription_number` VARCHAR(50) NOT NULL,
  `claim_submission_date` DATE NOT NULL,
  `adjudication_date` DATE NULL,
  `claim_amount` DECIMAL(12,2) NOT NULL,
  `copay_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `approved_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `settlement_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `claim_status` ENUM('APPROVED', 'REJECTED', 'PENDING') NOT NULL DEFAULT 'PENDING',
  `rejection_code` VARCHAR(30) NULL,
  `rejection_reason` VARCHAR(255) NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_claims_payer` FOREIGN KEY (`payer_id`) REFERENCES `payers` (`payer_id`),
  INDEX `idx_claims_pos` (`pos_sale_id`),
  INDEX `idx_claims_status` (`claim_status`),
  INDEX `idx_claims_sub_date` (`claim_submission_date`)
) ENGINE=InnoDB;

-- ------------------------------------------------------------------------------
-- Seed Data: insurance_claims_db
-- ------------------------------------------------------------------------------
INSERT INTO `payers` (`payer_id`, `payer_code`, `payer_name`, `payer_type`, `contact_email`, `phone`, `edi_claim_endpoint`, `average_turnaround_days`) VALUES
(1, 'BCBS-NAT',  'BlueCross BlueShield National', 'PRIVATE_PPO',        'edi@bcbs-health.com',   '+1-800-555-1000', 'https://edi.bcbs-health.com/v2/claims', 7),
(2, 'UNH-OPT',   'UnitedHealth / OptumRx',        'COMMERCIAL_HMO',     'pharmacy@optumrx.com',  '+1-800-555-2000', 'https://gateway.optumrx.com/claims', 5),
(3, 'MED-CMS',   'Medicare Part D (CMS)',         'GOVERNMENT',         'partd@cms.gov',         '+1-800-MEDICARE', 'https://cms-edi.gov/pharmacy', 14),
(4, 'AET-CVS',   'Aetna Health / Caremark',       'COMMERCIAL_HMO',     'adjudicate@aetna.com',  '+1-800-555-4000', 'https://claims.caremark.com/api', 6),
(5, 'CIG-EXPRES','Cigna Express Scripts',         'EMPLOYER_SPONSORED', 'claims@expressrx.com',  '+1-800-555-5000', 'https://express-scripts-api.com/v1', 8);

-- Realistic Claims: Approved, Rejected (with industry-standard rejection reasons), and Pending
INSERT INTO `claims` (`claim_id`, `claim_reference_number`, `pos_sale_id`, `payer_id`, `patient_policy_number`, `patient_member_id`, `prescription_number`, `claim_submission_date`, `adjudication_date`, `claim_amount`, `copay_amount`, `approved_amount`, `settlement_amount`, `claim_status`, `rejection_code`, `rejection_reason`) VALUES
(1, 'CLM-2026-00101', 1,  1, 'POL-BCBS-99104', 'MEM-88214', 'RX-2026-9041', '2026-08-05', '2026-08-07', 84.00,  15.00, 69.00,  69.00,  'APPROVED', NULL, NULL),
(2, 'CLM-2026-00102', 2,  2, 'POL-UNH-55018',  'MEM-33019', 'RX-2026-9042', '2026-08-12', '2026-08-14', 115.00, 25.00, 90.00,  90.00,  'APPROVED', NULL, NULL),
(3, 'CLM-2026-00103', 5,  3, 'POL-MED-10044',  'MEM-70192', 'RX-2026-9104', '2026-09-02', '2026-09-05', 73.50,  10.00, 63.50,  63.50,  'APPROVED', NULL, NULL),
(4, 'CLM-2026-00104', 8,  4, 'POL-AET-22891',  'MEM-44910', 'RX-2026-9130', '2026-09-28', '2026-10-01', 126.00, 0.00,  0.00,   0.00,   'REJECTED', 'PA_REQUIRED', 'Prior authorization required for high-tier brand statin therapy'),
(5, 'CLM-2026-00105', 9,  1, 'POL-BCBS-99104', 'MEM-88214', 'RX-2026-9201', '2026-10-02', '2026-10-04', 42.00,  10.00, 32.00,  32.00,  'APPROVED', NULL, NULL),
(6, 'CLM-2026-00106', 10, 2, 'POL-UNH-55018',  'MEM-33019', 'RX-2026-9214', '2026-10-08', NULL,         230.00, 30.00, 0.00,   0.00,   'PENDING',  NULL, NULL),
(7, 'CLM-2026-00107', 7,  5, 'POL-CIG-66120',  'MEM-55102', 'RX-2026-9122', '2026-09-19', '2026-09-22', 57.00,  0.00,  0.00,   0.00,   'REJECTED', 'MAX_QTY_LIMIT', 'Quantity requested exceeds allowable 30-day supply formulary limit'),
(8, 'CLM-2026-00108', 6,  4, 'POL-AET-88301',  'MEM-19024', 'RX-2026-9115', '2026-09-10', '2026-09-13', 50.00,  0.00,  0.00,   0.00,   'REJECTED', 'POLICY_INACTIVE', 'Patient coverage terminated prior to date of service');

SET FOREIGN_KEY_CHECKS = 1;

-- ==============================================================================
-- End of 01_sources_ddl_and_seed.sql
-- ==============================================================================
