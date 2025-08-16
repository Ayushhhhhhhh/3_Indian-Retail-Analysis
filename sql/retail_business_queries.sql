-- =====================================================
-- RETAIL BUSINESS ANALYTICS QUERIES
-- Author: Ayush Singhal
-- Purpose: Comprehensive Business Intelligence Analysis
-- =====================================================

USE retail_analytics_db;

-- =====================================================
-- EXECUTIVE DASHBOARD QUERIES
-- =====================================================

-- 1. Overall Business Performance KPIs
SELECT 
    'Business KPI Summary' as metric_category,
    CONCAT('₹', FORMAT(SUM(total_sales)/10000000, 1), ' Crores') as total_revenue,
    CONCAT('₹', FORMAT(SUM(total_profit)/10000000, 1), ' Crores') as total_profit,
    CONCAT(ROUND(AVG(avg_margin_pct), 2), '%') as overall_margin,
    FORMAT(SUM(total_customers), 0) as total_customers,
    COUNT(DISTINCT year) as years_analyzed,
    SUM(active_stores) as total_store_months
FROM monthly_performance;

-- 2. Monthly Performance Trends with Growth Analysis
SELECT 
    year,
    month_name,
    CONCAT('₹', FORMAT(total_sales/1000000, 1), 'M') as monthly_sales,
    CONCAT('₹', FORMAT(total_profit/1000000, 1), 'M') as monthly_profit,
    ROUND(avg_margin_pct, 2) as margin_percent,
    FORMAT(total_customers, 0) as customers,
    ROUND(
        ((total_sales - LAG(total_sales) OVER (ORDER BY year, month)) / 
         LAG(total_sales) OVER (ORDER BY year, month)) * 100, 1
    ) as mom_growth_percent
FROM monthly_performance
ORDER BY year, month;

-- 3. Chain Performance Ranking
SELECT 
    RANK() OVER (ORDER BY total_sales DESC) as sales_rank,
    RANK() OVER (ORDER BY avg_margin_pct DESC) as margin_rank,
    chain_name,
    chain_type,
    segment,
    store_count,
    CONCAT('₹', FORMAT(total_sales/10000000, 1), ' Cr') as revenue,
    ROUND(avg_margin_pct, 2) as margin_pct,
    FORMAT(total_customers, 0) as customers,
    ROUND(avg_satisfaction, 1) as satisfaction_score,
    CASE 
        WHEN avg_margin_pct > 8 THEN '🟢 Excellent'
        WHEN avg_margin_pct > 5 THEN '🟡 Good' 
        ELSE '🔴 Needs Improvement'
    END as performance_status
FROM chain_performance
ORDER BY total_sales DESC;

-- =====================================================
-- REGIONAL & GEOGRAPHIC ANALYSIS
-- =====================================================

-- 4. Regional Performance Deep Dive
SELECT 
    region,
    tier,
    store_count,
    city_count,
    CONCAT('₹', FORMAT(total_sales/10000000, 1), ' Cr') as revenue,
    CONCAT('₹', FORMAT(avg_sales_per_store/1000000, 1), 'M') as avg_per_store,
    ROUND(avg_margin_pct, 2) as margin_pct,
    FORMAT(total_customers, 0) as customers,
    ROUND(avg_basket_value, 0) as avg_basket_inr,
    ROUND(total_sales/store_count/1000000, 1) as productivity_score
FROM regional_analysis
ORDER BY total_sales DESC;

-- 5. City-wise Performance Analysis
SELECT 
    l.city,
    l.state,
    l.region,
    l.tier,
    COUNT(DISTINCT s.store_id) as stores,
    SUM(sf.sales_amount) as total_sales,
    AVG(sf.net_margin_pct) as avg_margin,
    SUM(sf.customer_count) as customers,
    ROUND(SUM(sf.sales_amount)/COUNT(DISTINCT s.store_id), 0) as sales_per_store,
    AVG(sf.customer_satisfaction_score) as satisfaction
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN locations l ON s.location_id = l.location_id
GROUP BY l.city, l.state, l.region, l.tier
HAVING stores >= 2  -- Only cities with multiple stores
ORDER BY total_sales DESC
LIMIT 15;

-- =====================================================
-- CATEGORY & PRODUCT ANALYSIS
-- =====================================================

-- 6. Category Performance with Profitability Analysis
SELECT 
    category_name,
    stores_selling,
    CONCAT('₹', FORMAT(total_sales/10000000, 1), ' Cr') as revenue,
    ROUND((total_sales / (SELECT SUM(total_sales) FROM category_performance)) * 100, 1) as revenue_share_pct,
    ROUND(avg_gross_margin, 1) as gross_margin_pct,
    ROUND(avg_net_margin, 1) as net_margin_pct,
    CONCAT('₹', FORMAT(total_profit/10000000, 1), ' Cr') as profit_contribution,
    FORMAT(total_customers, 0) as customers,
    FORMAT(total_items_sold, 0) as items_sold,
    ROUND(avg_turnover_ratio, 1) as inventory_turnover,
    CASE 
        WHEN avg_net_margin > 15 THEN '🌟 Star Category'
        WHEN avg_net_margin > 8 THEN '💰 Profitable'
        WHEN avg_net_margin > 0 THEN '⚖️ Break-even'
        ELSE '⚠️ Loss-making'
    END as category_status
FROM category_performance
ORDER BY total_sales DESC;

-- 7. Category Performance by Chain Matrix
SELECT 
    c.chain_name,
    cat.category_name,
    SUM(sf.sales_amount) as sales,
    AVG(sf.net_margin_pct) as margin_pct,
    SUM(sf.customer_count) as customers,
    RANK() OVER (PARTITION BY c.chain_name ORDER BY SUM(sf.sales_amount) DESC) as category_rank_in_chain
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN chains c ON s.chain_id = c.chain_id
JOIN categories cat ON sf.category_id = cat.category_id
GROUP BY c.chain_name, cat.category_name
ORDER BY c.chain_name, sales DESC;

-- =====================================================
-- STORE PERFORMANCE ANALYSIS  
-- =====================================================

-- 8. Top 10 and Bottom 10 Performing Stores
(SELECT 
    'Top Performers' as performance_type,
    store_id,
    chain_name,
    CONCAT(city, ', ', state) as location,
    tier,
    CONCAT('₹', FORMAT(total_sales/1000000, 1), 'M') as sales,
    ROUND(avg_margin_pct, 2) as margin_pct,
    FORMAT(total_customers, 0) as customers,
    ROUND(sales_per_sqft, 0) as sales_per_sqft,
    ROUND(avg_satisfaction, 1) as satisfaction
FROM top_stores
WHERE profit_rank <= 10
ORDER BY profit_rank)

UNION ALL

(SELECT 
    'Bottom Performers' as performance_type,
    store_id,
    chain_name,
    CONCAT(city, ', ', state) as location,
    tier,
    CONCAT('₹', FORMAT(total_sales/1000000, 1), 'M') as sales,
    ROUND(avg_margin_pct, 2) as margin_pct,
    FORMAT(total_customers, 0) as customers,
    ROUND(sales_per_sqft, 0) as sales_per_sqft,
    ROUND(avg_satisfaction, 1) as satisfaction
FROM top_stores
WHERE profit_rank > (SELECT COUNT(*) FROM top_stores) - 10
ORDER BY profit_rank DESC);

-- 9. Store Efficiency Analysis
SELECT 
    s.store_id,
    c.chain_name,
    l.city,
    l.tier,
    s.store_size_sqft,
    s.employee_count,
    SUM(sf.sales_amount) as total_sales,
    ROUND(SUM(sf.sales_amount) / s.store_size_sqft, 0) as sales_per_sqft,
    ROUND(SUM(sf.sales_amount) / s.employee_count, 0) as sales_per_employee,
    AVG(sf.net_margin_pct) as avg_margin,
    AVG(sf.customer_satisfaction_score) as satisfaction,
    CASE 
        WHEN SUM(sf.sales_amount) / s.store_size_sqft > 1000 THEN '🚀 High Efficiency'
        WHEN SUM(sf.sales_amount) / s.store_size_sqft > 500 THEN '📈 Good Efficiency'
        ELSE '⚡ Needs Optimization'
    END as efficiency_rating
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN chains c ON s.chain_id = c.chain_id
JOIN locations l ON s.location_id = l.location_id
GROUP BY s.store_id, c.chain_name, l.city, l.tier, s.store_size_sqft, s.employee_count
ORDER BY sales_per_sqft DESC;

-- =====================================================
-- TIME-BASED ANALYSIS
-- =====================================================

-- 10. Quarterly Performance Trends
SELECT 
    year,
    quarter,
    COUNT(DISTINCT sf.store_id) as active_stores,
    SUM(sf.sales_amount) as quarterly_sales,
    SUM(sf.net_profit) as quarterly_profit,
    AVG(sf.net_margin_pct) as avg_margin,
    SUM(sf.customer_count) as customers,
    ROUND(
        (SUM(sf.sales_amount) - LAG(SUM(sf.sales_amount)) OVER (ORDER BY year, quarter)) /
        LAG(SUM(sf.sales_amount)) OVER (ORDER BY year, quarter) * 100, 1
    ) as qoq_growth_pct
FROM sales_fact sf
JOIN time_dim t ON sf.date_id = t.date_id
GROUP BY year, quarter
ORDER BY year, quarter;

-- 11. Seasonal Pattern Analysis
SELECT 
    month_name,
    month,
    AVG(total_sales) as avg_monthly_sales,
    AVG(avg_margin_pct) as avg_margin,
    AVG(total_customers) as avg_customers,
    ROUND(
        (AVG(total_sales) / (SELECT AVG(total_sales) FROM monthly_performance) - 1) * 100, 1
    ) as vs_average_pct,
    CASE 
        WHEN month IN (10, 11) THEN '🪔 Festival Season'
        WHEN month IN (3, 4, 5) THEN '☀️ Summer Season'
        WHEN month IN (6, 7, 8) THEN '🌧️ Monsoon Season'
        ELSE '❄️ Regular Season'
    END as season_type
FROM monthly_performance
GROUP BY month, month_name
ORDER BY month;

-- =====================================================
-- CUSTOMER ANALYTICS
-- =====================================================

-- 12. Customer Behavior Analysis by Chain and Tier
SELECT 
    c.chain_name,
    l.tier,
    AVG(sf.avg_basket_value) as avg_basket_value,
    AVG(sf.avg_items_per_transaction) as avg_items_per_txn,
    AVG(sf.customer_satisfaction_score) as satisfaction,
    SUM(sf.customer_count) as total_customers,
    ROUND(SUM(sf.sales_amount) / SUM(sf.customer_count), 0) as revenue_per_customer,
    RANK() OVER (ORDER BY AVG(sf.avg_basket_value) DESC) as basket_value_rank
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN chains c ON s.chain_id = c.chain_id
JOIN locations l ON s.location_id = l.location_id
GROUP BY c.chain_name, l.tier
ORDER BY avg_basket_value DESC;

-- 13. Customer Satisfaction vs Performance Correlation
SELECT 
    CASE 
        WHEN AVG(sf.customer_satisfaction_score) >= 4.5 THEN 'Excellent (4.5+)'
        WHEN AVG(sf.customer_satisfaction_score) >= 4.0 THEN 'Good (4.0-4.4)'
        WHEN AVG(sf.customer_satisfaction_score) >= 3.5 THEN 'Average (3.5-3.9)'
        ELSE 'Below Average (<3.5)'
    END as satisfaction_tier,
    COUNT(DISTINCT s.store_id) as store_count,
    AVG(sf.net_margin_pct) as avg_profit_margin,
    AVG(sf.avg_basket_value) as avg_basket_value,
    SUM(sf.customer_count) as total_customers,
    ROUND(AVG(sf.customer_satisfaction_score), 2) as avg_satisfaction_score
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
GROUP BY satisfaction_tier
ORDER BY avg_satisfaction_score DESC;

-- =====================================================
-- OPERATIONAL EFFICIENCY METRICS
-- =====================================================

-- 14. Inventory Turnover Analysis
SELECT 
    cat.category_name,
    c.chain_name,
    AVG(sf.inventory_turnover_ratio) as avg_turnover_ratio,
    AVG(sf.gross_margin_pct) as avg_gross_margin,
    SUM(sf.total_items_sold) as total_items_sold,
    CASE 
        WHEN AVG(sf.inventory_turnover_ratio) > 12 THEN '🟢 Excellent'
        WHEN AVG(sf.inventory_turnover_ratio) > 8 THEN '🟡 Good'
        ELSE '🔴 Needs Improvement' 
    END as turnover_rating
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN chains c ON s.chain_id = c.chain_id
JOIN categories cat ON sf.category_id = cat.category_id
GROUP BY cat.category_name, c.chain_name
ORDER BY avg_turnover_ratio DESC;

-- 15. Cost Structure Analysis
SELECT 
    c.chain_name,
    l.tier,
    AVG(sf.sales_amount) as avg_monthly_sales,
    AVG(sf.staff_cost / sf.sales_amount * 100) as staff_cost_pct,
    AVG(sf.rent_cost / sf.sales_amount * 100) as rent_cost_pct,
    AVG(sf.utilities_cost / sf.sales_amount * 100) as utilities_cost_pct,
    AVG(sf.marketing_cost / sf.sales_amount * 100) as marketing_cost_pct,
    AVG(sf.total_operating_cost / sf.sales_amount * 100) as total_opex_pct,
    AVG(sf.net_margin_pct) as net_margin_pct
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN chains c ON s.chain_id = c.chain_id
JOIN locations l ON s.location_id = l.location_id
GROUP BY c.chain_name, l.tier
ORDER BY net_margin_pct DESC;

-- =====================================================
-- COMPETITIVE ANALYSIS
-- =====================================================

-- 16. Chain-wise Market Share Analysis
SELECT 
    chain_name,
    segment,
    CONCAT('₹', FORMAT(total_sales/10000000, 1), ' Cr') as revenue,
    ROUND(
        (total_sales / (SELECT SUM(total_sales) FROM chain_performance)) * 100, 1
    ) as market_share_pct,
    ROUND(avg_margin_pct, 2) as margin_pct,
    store_count,
    ROUND(total_sales / store_count / 1000000, 1) as avg_revenue_per_store_millions,
    RANK() OVER (ORDER BY total_sales DESC) as market_position
FROM chain_performance
ORDER BY total_sales DESC;

-- 17. Segment Performance Comparison
SELECT 
    segment,
    COUNT(DISTINCT chain_name) as chains_in_segment,
    SUM(store_count) as total_stores,
    SUM(total_sales) as segment_revenue,
    AVG(avg_margin_pct) as avg_segment_margin,
    AVG(avg_satisfaction) as avg_segment_satisfaction,
    ROUND(
        (SUM(total_sales) / (SELECT SUM(total_sales) FROM chain_performance)) * 100, 1
    ) as segment_market_share
FROM chain_performance
GROUP BY segment
ORDER BY segment_revenue DESC;

-- =====================================================
-- BUSINESS INSIGHTS & RECOMMENDATIONS
-- =====================================================

-- 18. Growth Opportunity Analysis
SELECT 
    'Growth Opportunities' as analysis_type,
    l.region,
    l.tier,
    COUNT(DISTINCT s.store_id) as current_stores,
    AVG(sf.sales_amount) as avg_store_performance,
    AVG(sf.net_margin_pct) as avg_margin,
    CASE 
        WHEN AVG(sf.net_margin_pct) > 8 AND COUNT(DISTINCT s.store_id) < 15 THEN 'High Priority Expansion'
        WHEN AVG(sf.net_margin_pct) > 5 AND COUNT(DISTINCT s.store_id) < 20 THEN 'Medium Priority Expansion'
        WHEN AVG(sf.net_margin_pct) < 3 THEN 'Optimization Required'
        ELSE 'Stable Market'
    END as recommendation
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN locations l ON s.location_id = l.location_id
GROUP BY l.region, l.tier
ORDER BY avg_margin DESC;

-- 19. Performance Alert System
SELECT 
    'Performance Alerts' as alert_type,
    s.store_id,
    c.chain_name,
    l.city,
    l.tier,
    ROUND(AVG(sf.net_margin_pct), 2) as avg_margin,
    ROUND(AVG(sf.customer_satisfaction_score), 1) as satisfaction,
    CASE 
        WHEN AVG(sf.net_margin_pct) < 0 THEN '🚨 Critical: Negative Margin'
        WHEN AVG(sf.net_margin_pct) < 2 THEN '⚠️ Warning: Low Margin'
        WHEN AVG(sf.customer_satisfaction_score) < 3.5 THEN '😞 Warning: Low Satisfaction'
        ELSE '✅ Performing Well'
    END as alert_level
FROM sales_fact sf
JOIN stores s ON sf.store_id = s.store_id
JOIN chains c ON s.chain_id = c.chain_id
JOIN locations l ON s.location_id = l.location_id
GROUP BY s.store_id, c.chain_name, l.city, l.tier
HAVING AVG(sf.net_margin_pct) < 3 OR AVG(sf.customer_satisfaction_score) < 3.5
ORDER BY avg_margin ASC;

-- 20. Executive Summary Query
SELECT 
    'RETAIL ANALYTICS EXECUTIVE SUMMARY' as report_title,
    CONCAT('₹', FORMAT(SUM(mp.total_sales)/10000000, 1), ' Crores') as total_revenue,
    CONCAT('₹', FORMAT(SUM(mp.total_profit)/10000000, 1), ' Crores') as total_profit,
    CONCAT(ROUND(AVG(mp.avg_margin_pct), 2), '%') as overall_margin,
    (SELECT chain_name FROM chain_performance ORDER BY total_sales DESC LIMIT 1) as top_chain_by_sales,
    (SELECT chain_name FROM chain_performance ORDER BY avg_margin_pct DESC LIMIT 1) as top_chain_by_margin,
    (SELECT category_name FROM category_performance ORDER BY total_sales DESC LIMIT 1) as top_category,
    (SELECT region FROM regional_analysis ORDER BY total_sales DESC LIMIT 1) as top_region,
    COUNT(DISTINCT DATE_FORMAT(CONCAT(mp.year, '-', mp.month, '-01'), '%Y-%m')) as months_analyzed,
    'Analysis by Ayush Singhal' as analyst
FROM monthly_performance mp;

-- Final success message
SELECT 
    'Business Intelligence Queries Executed Successfully!' as status,
    '20 comprehensive analysis queries completed' as summary,
    'Ready for dashboard creation and reporting' as next_step,
    NOW() as execution_time;