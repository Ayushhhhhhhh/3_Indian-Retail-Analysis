-- =====================================================
-- INDIAN RETAIL CHAIN DATABASE SCHEMA
-- Author: Ayush Singhal  
-- Purpose: Business Analytics Database Design
-- =====================================================

CREATE DATABASE IF NOT EXISTS retail_analytics_db;
USE retail_analytics_db;

-- Drop existing tables if they exist
DROP TABLE IF EXISTS sales_fact;
DROP TABLE IF EXISTS stores;
DROP TABLE IF EXISTS time_dim;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS chains;
DROP TABLE IF EXISTS locations;

-- =====================================================
-- DIMENSION TABLES
-- =====================================================

-- Retail Chains Master
CREATE TABLE chains (
    chain_id INT AUTO_INCREMENT PRIMARY KEY,
    chain_name VARCHAR(50) NOT NULL UNIQUE,
    chain_type ENUM('Hypermarket', 'Supermarket', 'Department Store') NOT NULL,
    segment ENUM('Value', 'Mid-range', 'Premium') NOT NULL,
    founded_year INT,
    headquarters VARCHAR(50),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_chain_name (chain_name),
    INDEX idx_segment (segment)
);

-- Geographic Locations
CREATE TABLE locations (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    region ENUM('North', 'South', 'East', 'West', 'Central') NOT NULL,
    tier ENUM('Metro', 'Tier_1', 'Tier_2', 'Tier_3') NOT NULL,
    population_millions DECIMAL(4,2),
    avg_income_lakhs DECIMAL(5,2),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_city (city),
    INDEX idx_region (region),
    INDEX idx_tier (tier)
);

-- Product Categories
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    subcategory VARCHAR(50),
    typical_margin_pct DECIMAL(5,2),
    seasonal_factor DECIMAL(4,2) DEFAULT 1.00,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_category (category_name)
);

-- Time Dimension
CREATE TABLE time_dim (
    date_id DATE PRIMARY KEY,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(15) NOT NULL,
    day_of_month INT NOT NULL,
    day_of_week INT NOT NULL,
    day_name VARCHAR(15) NOT NULL,
    is_weekend BOOLEAN DEFAULT FALSE,
    is_holiday BOOLEAN DEFAULT FALSE,
    fiscal_year INT,
    fiscal_quarter INT,
    INDEX idx_year_month (year, month),
    INDEX idx_quarter (quarter),
    INDEX idx_weekend (is_weekend)
);

-- Stores Master
CREATE TABLE stores (
    store_id VARCHAR(20) PRIMARY KEY,
    chain_id INT NOT NULL,
    location_id INT NOT NULL,
    store_size_sqft INT NOT NULL,
    opening_date DATE NOT NULL,
    manager_name VARCHAR(100),
    employee_count INT DEFAULT 0,
    monthly_rent_inr DECIMAL(10,2),
    parking_spaces INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (chain_id) REFERENCES chains(chain_id),
    FOREIGN KEY (location_id) REFERENCES locations(location_id),
    INDEX idx_chain_location (chain_id, location_id),
    INDEX idx_opening_date (opening_date),
    INDEX idx_active (is_active)
);

-- =====================================================
-- FACT TABLE
-- =====================================================

-- Sales Performance Facts
CREATE TABLE sales_fact (
    record_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    store_id VARCHAR(20) NOT NULL,
    category_id INT NOT NULL,
    date_id DATE NOT NULL,
    
    -- Sales Metrics
    sales_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    cost_of_goods DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    gross_profit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    gross_margin_pct DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    
    -- Operating Costs
    staff_cost DECIMAL(10,2) DEFAULT 0.00,
    rent_cost DECIMAL(10,2) DEFAULT 0.00,
    utilities_cost DECIMAL(10,2) DEFAULT 0.00,
    marketing_cost DECIMAL(10,2) DEFAULT 0.00,
    other_operating_cost DECIMAL(10,2) DEFAULT 0.00,
    total_operating_cost DECIMAL(12,2) DEFAULT 0.00,
    
    -- Profitability
    net_profit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    net_margin_pct DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    
    -- Customer Metrics
    customer_count INT DEFAULT 0,
    avg_basket_value DECIMAL(8,2) DEFAULT 0.00,
    total_items_sold INT DEFAULT 0,
    avg_items_per_transaction DECIMAL(4,2) DEFAULT 0.00,
    
    -- Operational Metrics
    inventory_turnover_ratio DECIMAL(4,2) DEFAULT 0.00,
    customer_satisfaction_score DECIMAL(2,1) DEFAULT 0.0,
    
    -- Audit Fields
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (category_id) REFERENCES categories(category_id),
    FOREIGN KEY (date_id) REFERENCES time_dim(date_id),
    
    INDEX idx_store_date (store_id, date_id),
    INDEX idx_category_date (category_id, date_id),
    INDEX idx_date (date_id),
    INDEX idx_sales_amount (sales_amount),
    INDEX idx_net_profit (net_profit),
    INDEX idx_customer_count (customer_count)
);

-- =====================================================
-- BUSINESS INTELLIGENCE VIEWS
-- =====================================================

-- Monthly Performance Summary
CREATE VIEW monthly_performance AS
SELECT 
    t.year,
    t.month,
    t.month_name,
    t.quarter,
    COUNT(DISTINCT s.store_id) as active_stores,
    SUM(sf.sales_amount) as total_sales,
    SUM(sf.net_profit) as total_profit,
    AVG(sf.net_margin_pct) as avg_margin_pct,
    SUM(sf.customer_count) as total_customers,
    AVG(sf.avg_basket_value) as avg_basket_value,
    SUM(sf.total_items_sold) as total_items_sold
FROM sales_fact sf
JOIN time_dim t ON sf.date_id = t.date_id
JOIN stores s ON sf.store_id = s.store_id
GROUP BY t.year, t.month, t.month_name, t.quarter
ORDER BY t.year, t.month;

-- Chain Performance View
CREATE VIEW chain_performance AS
SELECT 
    c.chain_name,
    c.chain_type,
    c.segment,
    COUNT(DISTINCT s.store_id) as store_count,
    SUM(sf.sales_amount) as total_sales,
    AVG(sf.sales_amount) as avg_monthly_sales,
    SUM(sf.net_profit) as total_profit,
    AVG(sf.net_margin_pct) as avg_margin_pct,
    SUM(sf.customer_count) as total_customers,
    AVG(sf.customer_satisfaction_score) as avg_satisfaction,
    AVG(sf.inventory_turnover_ratio) as avg_inventory_turnover
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN chains c ON s.chain_id = c.chain_id
GROUP BY c.chain_id, c.chain_name, c.chain_type, c.segment
ORDER BY total_sales DESC;

-- Regional Analysis View
CREATE VIEW regional_analysis AS
SELECT 
    l.region,
    l.tier,
    COUNT(DISTINCT s.store_id) as store_count,
    COUNT(DISTINCT l.city) as city_count,
    SUM(sf.sales_amount) as total_sales,
    AVG(sf.sales_amount) as avg_sales_per_store,
    SUM(sf.net_profit) as total_profit,
    AVG(sf.net_margin_pct) as avg_margin_pct,
    SUM(sf.customer_count) as total_customers,
    AVG(sf.avg_basket_value) as avg_basket_value
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN locations l ON s.location_id = l.location_id
GROUP BY l.region, l.tier
ORDER BY total_sales DESC;

-- Category Performance View
CREATE VIEW category_performance AS
SELECT 
    cat.category_name,
    cat.subcategory,
    COUNT(DISTINCT sf.store_id) as stores_selling,
    SUM(sf.sales_amount) as total_sales,
    AVG(sf.sales_amount) as avg_monthly_sales,
    SUM(sf.net_profit) as total_profit,
    AVG(sf.gross_margin_pct) as avg_gross_margin,
    AVG(sf.net_margin_pct) as avg_net_margin,
    SUM(sf.customer_count) as total_customers,
    SUM(sf.total_items_sold) as total_items_sold,
    AVG(sf.inventory_turnover_ratio) as avg_turnover_ratio
FROM sales_fact sf
JOIN categories cat ON sf.category_id = cat.category_id
GROUP BY cat.category_id, cat.category_name, cat.subcategory
ORDER BY total_sales DESC;

-- Top Performing Stores View
CREATE VIEW top_stores AS
SELECT 
    s.store_id,
    c.chain_name,
    l.city,
    l.state,
    l.tier,
    s.store_size_sqft,
    SUM(sf.sales_amount) as total_sales,
    SUM(sf.net_profit) as total_profit,
    AVG(sf.net_margin_pct) as avg_margin_pct,
    SUM(sf.customer_count) as total_customers,
    ROUND(SUM(sf.sales_amount) / s.store_size_sqft, 2) as sales_per_sqft,
    AVG(sf.customer_satisfaction_score) as avg_satisfaction,
    RANK() OVER (ORDER BY AVG(sf.net_margin_pct) DESC) as profit_rank,
    RANK() OVER (ORDER BY SUM(sf.sales_amount) DESC) as sales_rank
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN chains c ON s.chain_id = c.chain_id
JOIN locations l ON s.location_id = l.location_id
GROUP BY s.store_id, c.chain_name, l.city, l.state, l.tier, s.store_size_sqft
ORDER BY avg_margin_pct DESC;

-- =====================================================
-- STORED PROCEDURES
-- =====================================================

DELIMITER //

-- Get Performance by Date Range
CREATE PROCEDURE GetPerformanceByDateRange(
    IN start_date DATE,
    IN end_date DATE
)
BEGIN
    SELECT 
        'Performance Summary' as report_type,
        COUNT(DISTINCT sf.store_id) as active_stores,
        SUM(sf.sales_amount) as total_sales,
        SUM(sf.net_profit) as total_profit,
        AVG(sf.net_margin_pct) as avg_margin,
        SUM(sf.customer_count) as total_customers,
        AVG(sf.customer_satisfaction_score) as avg_satisfaction
    FROM sales_fact sf
    WHERE sf.date_id BETWEEN start_date AND end_date;
END //

-- Chain Comparison Analysis
CREATE PROCEDURE CompareChainPerformance(
    IN chain1 VARCHAR(50),
    IN chain2 VARCHAR(50)
)
BEGIN
    SELECT 
        c.chain_name,
        COUNT(DISTINCT s.store_id) as stores,
        SUM(sf.sales_amount) as total_sales,
        AVG(sf.net_margin_pct) as avg_margin,
        SUM(sf.customer_count) as customers,
        AVG(sf.customer_satisfaction_score) as satisfaction
    FROM sales_fact sf
    JOIN stores s ON sf.store_id = s.store_id  
    JOIN chains c ON s.chain_id = c.chain_id
    WHERE c.chain_name IN (chain1, chain2)
    GROUP BY c.chain_name
    ORDER BY total_sales DESC;
END //

-- Store Performance Alert
CREATE PROCEDURE IdentifyUnderperformingStores(
    IN margin_threshold DECIMAL(5,2)
)
BEGIN
    SELECT 
        s.store_id,
        c.chain_name,
        l.city,
        l.tier,
        AVG(sf.net_margin_pct) as avg_margin,
        SUM(sf.sales_amount) as total_sales,
        AVG(sf.customer_satisfaction_score) as satisfaction,
        'Requires Attention' as status
    FROM sales_fact sf
    JOIN stores s ON sf.store_id = s.store_id
    JOIN chains c ON s.chain_id = c.chain_id
    JOIN locations l ON s.location_id = l.location_id
    GROUP BY s.store_id, c.chain_name, l.city, l.tier
    HAVING avg_margin < margin_threshold
    ORDER BY avg_margin ASC;
END //

DELIMITER ;

-- =====================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- =====================================================

-- Composite indexes for common query patterns
CREATE INDEX idx_sales_fact_composite ON sales_fact (store_id, date_id, category_id);
CREATE INDEX idx_sales_fact_performance ON sales_fact (sales_amount, net_profit, net_margin_pct);
CREATE INDEX idx_sales_fact_date_amount ON sales_fact (date_id, sales_amount);

-- Covering indexes for reporting queries
CREATE INDEX idx_sales_fact_summary ON sales_fact (date_id, store_id, sales_amount, net_profit, customer_count);

-- =====================================================
-- SAMPLE DATA INSERTION
-- =====================================================

-- Insert reference data
INSERT INTO chains (chain_name, chain_type, segment, founded_year, headquarters) VALUES
('BigBazaar', 'Hypermarket', 'Value', 2001, 'Mumbai'),
('Reliance Fresh', 'Supermarket', 'Premium', 2006, 'Mumbai'),  
('D-Mart', 'Supermarket', 'Value', 2002, 'Mumbai'),
('Spencer\'s Retail', 'Supermarket', 'Premium', 1863, 'Chennai'),
('More Megastore', 'Supermarket', 'Mid-range', 2008, 'Delhi'),
('Star Bazaar', 'Hypermarket', 'Mid-range', 2005, 'Mumbai');

INSERT INTO categories (category_name, subcategory, typical_margin_pct) VALUES
('Groceries', 'Rice & Grains', 11.50),
('Groceries', 'Dal & Pulses', 11.50),
('Fresh Produce', 'Vegetables', 25.00),
('Fresh Produce', 'Fruits', 25.00),
('Personal Care', 'Bath & Body', 32.50),
('Personal Care', 'Hair Care', 32.50),
('Home Care', 'Detergents', 22.90),
('Home Care', 'Cleaning Supplies', 22.90),
('Electronics', 'Mobile Accessories', 17.00),
('Electronics', 'Home Appliances', 17.00),
('Fashion', 'Clothing', 45.00),
('Fashion', 'Footwear', 45.00);

-- Success message
SELECT 
    'Database Schema Created Successfully!' as status,
    'Ready for retail analytics data import' as next_step,
    'Author: Ayush Singhal' as created_by,
    NOW() as created_timestamp;