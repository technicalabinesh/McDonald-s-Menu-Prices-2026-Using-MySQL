-- McDonald's Menu Analytics Project
-- SQL dialect: MySQL 8.0+
-- Note: This script creates the database and table, then provides analysis queries.
-- Import your CSV into menu_items after creating the table.
-- Add any remaining dataset columns before importing if your source has more fields.

CREATE DATABASE IF NOT EXISTS mcdonalds_analysis;
USE mcdonalds_analysis;

CREATE TABLE IF NOT EXISTS menu_items (
    item_id VARCHAR(30) PRIMARY KEY,
    item_name VARCHAR(150) NOT NULL,
    category VARCHAR(100),
    description TEXT,
    price_usd DECIMAL(8,2),
    calories INT,
    calories_from_fat INT,
    total_fat_g DECIMAL(8,2),
    saturated_fat_g DECIMAL(8,2),
    trans_fat_g DECIMAL(8,2),
    CHECK (price_usd IS NULL OR price_usd >= 0),
    CHECK (calories IS NULL OR calories >= 0),
    CHECK (calories_from_fat IS NULL OR calories_from_fat >= 0),
    CHECK (total_fat_g IS NULL OR total_fat_g >= 0),
    CHECK (saturated_fat_g IS NULL OR saturated_fat_g >= 0),
    CHECK (trans_fat_g IS NULL OR trans_fat_g >= 0)
);

-- =========================
-- 1. DATA EXPLORATION
-- =========================

-- Total rows
SELECT COUNT(*) AS total_items
FROM menu_items;

-- Preview records
SELECT *
FROM menu_items
LIMIT 10;

-- Distinct menu categories
SELECT DISTINCT category
FROM menu_items
ORDER BY category;

-- Items per category
SELECT category, COUNT(*) AS item_count
FROM menu_items
GROUP BY category
ORDER BY item_count DESC;

-- Duplicate item IDs (normally prevented by the primary key)
SELECT item_id, COUNT(*) AS occurrences
FROM menu_items
GROUP BY item_id
HAVING COUNT(*) > 1;

-- Missing-value summary for key columns
SELECT
    SUM(item_name IS NULL OR TRIM(item_name) = '') AS missing_item_names,
    SUM(category IS NULL OR TRIM(category) = '') AS missing_categories,
    SUM(price_usd IS NULL) AS missing_prices,
    SUM(calories IS NULL) AS missing_calories
FROM menu_items;

-- =========================
-- 2. PRICE & CALORIE ANALYSIS
-- =========================

SELECT
    ROUND(AVG(price_usd), 2) AS avg_price_usd,
    MIN(price_usd) AS min_price_usd,
    MAX(price_usd) AS max_price_usd,
    ROUND(AVG(calories), 2) AS avg_calories,
    MIN(calories) AS min_calories,
    MAX(calories) AS max_calories
FROM menu_items;

-- 10 most expensive items
SELECT item_name, category, price_usd
FROM menu_items
WHERE price_usd IS NOT NULL
ORDER BY price_usd DESC
LIMIT 10;

-- 10 highest-calorie items
SELECT item_name, category, calories
FROM menu_items
WHERE calories IS NOT NULL
ORDER BY calories DESC
LIMIT 10;

-- Average price and calories by category
SELECT
    category,
    COUNT(*) AS item_count,
    ROUND(AVG(price_usd), 2) AS avg_price_usd,
    ROUND(AVG(calories), 2) AS avg_calories
FROM menu_items
GROUP BY category
ORDER BY avg_calories DESC;

-- Items over 500 calories (analysis threshold, not a medical recommendation)
SELECT item_name, category, calories, price_usd
FROM menu_items
WHERE calories > 500
ORDER BY calories DESC;

-- =========================
-- 3. NUTRITION ANALYSIS
-- =========================

-- Highest saturated fat
SELECT item_name, category, saturated_fat_g, calories
FROM menu_items
WHERE saturated_fat_g IS NOT NULL
ORDER BY saturated_fat_g DESC
LIMIT 10;

-- Percentage of calories from fat, where both fields are available
SELECT
    item_name,
    calories,
    calories_from_fat,
    ROUND(100.0 * calories_from_fat / NULLIF(calories, 0), 2)
        AS fat_calorie_percentage
FROM menu_items
WHERE calories > 0
  AND calories_from_fat IS NOT NULL
ORDER BY fat_calorie_percentage DESC;

-- Nutritional outliers relative to category average
WITH category_nutrition AS (
    SELECT
        item_id,
        item_name,
        category,
        calories,
        AVG(calories) OVER (PARTITION BY category) AS category_avg_calories
    FROM menu_items
    WHERE calories IS NOT NULL
)
SELECT
    item_name,
    category,
    calories,
    ROUND(category_avg_calories, 2) AS category_avg_calories,
    ROUND(calories - category_avg_calories, 2) AS difference_from_category_avg
FROM category_nutrition
WHERE calories > category_avg_calories
ORDER BY difference_from_category_avg DESC;

-- =========================
-- 4. ADVANCED SQL
-- =========================

-- Rank items by price within each category
SELECT
    item_name,
    category,
    price_usd,
    RANK() OVER (
        PARTITION BY category
        ORDER BY price_usd DESC
    ) AS price_rank
FROM menu_items
WHERE price_usd IS NOT NULL;

-- Items priced above their category average
WITH category_prices AS (
    SELECT
        item_name,
        category,
        price_usd,
        AVG(price_usd) OVER (PARTITION BY category) AS avg_category_price
    FROM menu_items
    WHERE price_usd IS NOT NULL
)
SELECT
    item_name,
    category,
    price_usd,
    ROUND(avg_category_price, 2) AS avg_category_price
FROM category_prices
WHERE price_usd > avg_category_price
ORDER BY category, price_usd DESC;

-- Compare average price and average calories by category
SELECT
    category,
    ROUND(AVG(price_usd), 2) AS avg_price_usd,
    ROUND(AVG(calories), 2) AS avg_calories,
    COUNT(*) AS item_count
FROM menu_items
GROUP BY category
HAVING COUNT(*) >= 2
ORDER BY avg_price_usd DESC;

-- =========================
-- 5. OPTIONAL CORRELATION CHECK
-- =========================
-- MySQL does not provide CORR() in all standard installations.
-- Export price_usd and calories to a stats tool or use a supported
-- statistics extension if you need a formal correlation coefficient.
-- This query provides the data for visual inspection:
SELECT item_name, category, price_usd, calories
FROM menu_items
WHERE price_usd IS NOT NULL
  AND calories IS NOT NULL
ORDER BY price_usd;
