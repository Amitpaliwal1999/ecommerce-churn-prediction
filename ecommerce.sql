--  E-COMMERCE CUSTOMER CHURN PREDICTION
--  Dataset: 5,630 customers | 20 columns | 16.84% churn rate

CREATE DATABASE ecommerce_churn;
USE ecommerce_churn;

SHOW DATABASES;

CREATE TABLE customers_raw (
    CustomerID                    INT,
    Churn                         INT,
    Tenure                        FLOAT,
    PreferredLoginDevice          VARCHAR(50),
    CityTier                      INT,
    WarehouseToHome               FLOAT,
    PreferredPaymentMode          VARCHAR(50),
    Gender                        VARCHAR(20),
    HourSpendOnApp                FLOAT,
    NumberOfDeviceRegistered      INT,
    PreferedOrderCat              VARCHAR(50),
    SatisfactionScore             INT,
    MaritalStatus                 VARCHAR(20),
    NumberOfAddress               INT,
    Complain                      INT,
    OrderAmountHikeFromlastYear   FLOAT,
    CouponUsed                    FLOAT,
    OrderCount                    FLOAT,
    DaySinceLastOrder             FLOAT,
    CashbackAmount                FLOAT
);

--  IMPORT CSV DATA USING IMPORT WIZARD

SELECT COUNT(*) AS total_rows FROM customers_raw;
-- Expected: 5630


--  DATA CLEANING
--  Check nulls before cleaning
SELECT
    SUM(CASE WHEN Tenure                     IS NULL THEN 1 ELSE 0 END) AS null_Tenure,
    SUM(CASE WHEN WarehouseToHome            IS NULL THEN 1 ELSE 0 END) AS null_WarehouseToHome,
    SUM(CASE WHEN HourSpendOnApp             IS NULL THEN 1 ELSE 0 END) AS null_HourSpendOnApp,
    SUM(CASE WHEN OrderAmountHikeFromlastYear IS NULL THEN 1 ELSE 0 END) AS null_OrderAmountHike,
    SUM(CASE WHEN CouponUsed                 IS NULL THEN 1 ELSE 0 END) AS null_CouponUsed,
    SUM(CASE WHEN OrderCount                 IS NULL THEN 1 ELSE 0 END) AS null_OrderCount,
    SUM(CASE WHEN DaySinceLastOrder          IS NULL THEN 1 ELSE 0 END) AS null_DaySinceLastOrder
FROM customers_raw;
-- Expected: 264 | 251 | 255 | 265 | 256 | 258 | 307

--  Check dirty categorical values before fixing
SELECT PreferredPaymentMode, COUNT(*) AS count
FROM customers_raw
GROUP BY PreferredPaymentMode
ORDER BY count DESC;
-- Problem: 'CC' (273 rows) = same as 'Credit Card'
--          'Cash on Delivery' (149 rows) = same as 'COD'

SELECT PreferedOrderCat, COUNT(*) AS count
FROM customers_raw
GROUP BY PreferedOrderCat
ORDER BY count DESC;
-- Problem: 'Mobile' (809 rows) = same as 'Mobile Phone'

SELECT PreferredLoginDevice, COUNT(*) AS count
FROM customers_raw
GROUP BY PreferredLoginDevice
ORDER BY count DESC;
-- Clean — no duplicates, no action needed


-- Creating the CLEAN table with all fixes applied
-- This is the main cleaning step.
-- COALESCE = fillna(median) in Python
-- CASE WHEN = .replace() in Python
-- Medians are calculated from your actual dataset

DROP TABLE IF EXISTS customers;

CREATE TABLE customers AS
SELECT
    CustomerID,
    Churn,

    -- Fix nulls: fill each column with its median value
    -- (same medians as used in Google Colab)
    COALESCE(Tenure,                      9.0)  AS Tenure,
    COALESCE(WarehouseToHome,            14.0)  AS WarehouseToHome,
    COALESCE(HourSpendOnApp,              3.0)  AS HourSpendOnApp,
    COALESCE(OrderAmountHikeFromlastYear,15.0)  AS OrderAmountHikeFromlastYear,
    COALESCE(CouponUsed,                  1.0)  AS CouponUsed,
    COALESCE(OrderCount,                  2.0)  AS OrderCount,
    COALESCE(DaySinceLastOrder,           3.0)  AS DaySinceLastOrder,

    -- Fix dirty categories: PreferredPaymentMode
    -- 'CC' → 'Credit Card' | 'Cash on Delivery' → 'COD'
    CASE PreferredPaymentMode
        WHEN 'CC'               THEN 'Credit Card'
        WHEN 'Cash on Delivery' THEN 'COD'
        ELSE PreferredPaymentMode
    END AS PreferredPaymentMode,

    -- Fix dirty categories: PreferedOrderCat
    -- 'Mobile' → 'Mobile Phone'
    CASE PreferedOrderCat
        WHEN 'Mobile' THEN 'Mobile Phone'
        ELSE PreferedOrderCat
    END AS PreferedOrderCat,

    -- Clean columns — copy as-is (no issues found)
    PreferredLoginDevice,
    CityTier,
    Gender,
    NumberOfDeviceRegistered,
    SatisfactionScore,
    MaritalStatus,
    NumberOfAddress,
    Complain,
    CashbackAmount

FROM customers_raw;
-- Expected output: 5630 row(s) affected
-- New table 'customers' appears in left panel


-- Verify cleaning worked correctly

-- 1: Row count must still be 5630
SELECT COUNT(*) AS total_rows FROM customers;
-- Expected: 5630

-- 2: Zero nulls remaining
SELECT COUNT(*) AS remaining_nulls
FROM customers
WHERE Tenure IS NULL
   OR WarehouseToHome IS NULL
   OR HourSpendOnApp IS NULL
   OR OrderAmountHikeFromlastYear IS NULL
   OR CouponUsed IS NULL
   OR OrderCount IS NULL
   OR DaySinceLastOrder IS NULL;
-- Expected: 0

-- 3: Dirty payment values gone
SELECT PreferredPaymentMode, COUNT(*) AS count
FROM customers
GROUP BY PreferredPaymentMode
ORDER BY count DESC;
-- 'CC' and 'Cash on Delivery' must NOT appear
-- Credit Card = 1774 | COD = 514

-- 4: Dirty order category gone
SELECT PreferedOrderCat, COUNT(*) AS count
FROM customers
GROUP BY PreferedOrderCat
ORDER BY count DESC;
-- 'Mobile' must NOT appear
-- Mobile Phone = 2080

-- All 4 checks pass → data is 100% clean

--  STEP 6 — EXPLORATORY OVERVIEW
--  Quick summary before analysis queries

-- Overall dataset summary
SELECT
    COUNT(*)                                    AS total_customers,
    SUM(Churn)                                  AS churned,
    COUNT(*) - SUM(Churn)                       AS retained,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(Tenure), 1)                       AS avg_tenure_months,
    ROUND(AVG(OrderCount), 2)                   AS avg_orders,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(SatisfactionScore), 2)            AS avg_satisfaction,
    SUM(Complain)                               AS total_complaints
FROM customers;
-- Expected: 5630 total | 948 churned | 16.84% churn rate

--  MYSQL TASK 1 — ANALYZE REPEAT CUSTOMERS
--  Finding: 3,879 repeat customers (68.9%) | churn 16.29%
--           1,751 one-time customers (31.1%) | churn 18.05%

-- T1.1: Repeat vs one-time customer comparison
SELECT
    CASE WHEN OrderCount > 1 THEN 'Repeat Customer'
         ELSE                     'One-Time Customer'
    END                                         AS customer_type,
    COUNT(*)                                    AS total_customers,
    ROUND(COUNT(*)/5630*100, 1)                 AS pct_of_total,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(Tenure), 1)                       AS avg_tenure_months,
    ROUND(AVG(OrderCount), 2)                   AS avg_orders,
    ROUND(AVG(HourSpendOnApp), 2)               AS avg_hours_on_app
FROM customers
GROUP BY customer_type
ORDER BY total_customers DESC;


-- T1.2: Repeat rate by order category
SELECT
    PreferedOrderCat                            AS order_category,
    COUNT(*)                                    AS total_customers,
    SUM(CASE WHEN OrderCount > 1 THEN 1 END)    AS repeat_customers,
    ROUND(SUM(CASE WHEN OrderCount > 1 THEN 1 END)/COUNT(*)*100, 2)
                                                AS repeat_rate_pct,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback
FROM customers
GROUP BY PreferedOrderCat
ORDER BY repeat_rate_pct DESC;


-- T1.3: Repeat rate by payment mode
SELECT
    PreferredPaymentMode,
    COUNT(*)                                    AS total_customers,
    SUM(CASE WHEN OrderCount > 1 THEN 1 END)    AS repeat_customers,
    ROUND(SUM(CASE WHEN OrderCount > 1 THEN 1 END)/COUNT(*)*100, 2)
                                                AS repeat_rate_pct,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY PreferredPaymentMode
ORDER BY repeat_rate_pct DESC;


-- T1.4: Repeat rate by marital status
SELECT
    MaritalStatus,
    COUNT(*)                                    AS total_customers,
    SUM(CASE WHEN OrderCount > 1 THEN 1 END)    AS repeat_customers,
    ROUND(SUM(CASE WHEN OrderCount > 1 THEN 1 END)/COUNT(*)*100, 2)
                                                AS repeat_rate_pct,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback
FROM customers
GROUP BY MaritalStatus
ORDER BY repeat_rate_pct DESC;


-- T1.5: Top 20 most loyal customers
SELECT
    CustomerID, OrderCount, Tenure,
    ROUND(CashbackAmount, 2)                    AS cashback,
    SatisfactionScore, MaritalStatus,
    PreferedOrderCat, PreferredPaymentMode, Churn
FROM customers
WHERE OrderCount >= 7
ORDER BY OrderCount DESC, CashbackAmount DESC
LIMIT 20;

--  MYSQL TASK 2 — CUSTOMER PURCHASE FREQUENCY
--  Finding: Regular buyers (4-6 orders) = lowest churn 11.11%
--           One-time buyers = highest churn 18.05%

-- T2.1: Purchase frequency band analysis
SELECT
    CASE
        WHEN OrderCount = 1             THEN '1. One-Time   (1 order)'
        WHEN OrderCount BETWEEN 2 AND 3 THEN '2. Occasional (2-3 orders)'
        WHEN OrderCount BETWEEN 4 AND 6 THEN '3. Regular    (4-6 orders)'
        ELSE                                 '4. Frequent   (7+ orders)'
    END                                         AS frequency_band,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(Tenure), 1)                       AS avg_tenure_months,
    ROUND(AVG(CouponUsed), 2)                   AS avg_coupons_used,
    ROUND(AVG(HourSpendOnApp), 2)               AS avg_app_hours
FROM customers
GROUP BY frequency_band
ORDER BY frequency_band;
-- Key: Regular(4-6) = 11.11% churn (LOWEST)


-- T2.2: Full order count distribution
SELECT
    CAST(OrderCount AS UNSIGNED)                AS order_count,
    COUNT(*)                                    AS customers,
    ROUND(COUNT(*)/5630*100, 2)                 AS pct_of_total,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY order_count
ORDER BY order_count;


-- T2.3: Frequency vs coupon and app usage
SELECT
    CASE
        WHEN OrderCount = 1             THEN 'One-Time'
        WHEN OrderCount BETWEEN 2 AND 3 THEN 'Occasional'
        WHEN OrderCount BETWEEN 4 AND 6 THEN 'Regular'
        ELSE                                 'Frequent'
    END                                         AS frequency_band,
    ROUND(AVG(CouponUsed), 2)                   AS avg_coupons,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(HourSpendOnApp), 2)               AS avg_app_hours,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY frequency_band
ORDER BY churn_rate_pct DESC;

-- T2.4: Frequency by city tier
SELECT
    CityTier,
    COUNT(*)                                    AS customers,
    ROUND(AVG(OrderCount), 2)                   AS avg_orders,
    SUM(CASE WHEN OrderCount >= 4 THEN 1 END)   AS high_freq_customers,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY CityTier
ORDER BY CityTier;

--  MYSQL TASK 3 — REVENUE BY CUSTOMER SEGMENT
--  Using CashbackAmount as revenue / CLV proxy
--  Finding: Premium ($300+) = 6.17% churn
--           Mid-value ($100-200) = biggest segment with 18.90% churn

-- T3.1: CLV segment analysis
SELECT
    CASE
        WHEN CashbackAmount < 100  THEN '1. Low Value  (< $100)'
        WHEN CashbackAmount < 200  THEN '2. Mid Value  ($100-200)'
        WHEN CashbackAmount < 300  THEN '3. High Value ($200-300)'
        ELSE                            '4. Premium    ($300+)'
    END                                         AS clv_segment,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(SUM(CashbackAmount), 2)               AS total_cashback,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(OrderCount), 2)                   AS avg_orders,
    ROUND(AVG(Tenure), 1)                       AS avg_tenure_months
FROM customers
GROUP BY clv_segment
ORDER BY clv_segment;


-- T3.2: Revenue by order category
SELECT
    PreferedOrderCat,
    COUNT(*)                                    AS customers,
    ROUND(SUM(CashbackAmount), 2)               AS total_cashback,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(SUM(CashbackAmount * OrderCount), 2)  AS estimated_revenue,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY PreferedOrderCat
ORDER BY total_cashback DESC;


-- T3.3: Revenue by city tier
SELECT
    CityTier,
    COUNT(*)                                    AS customers,
    ROUND(SUM(CashbackAmount), 2)               AS total_cashback,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY CityTier
ORDER BY total_cashback DESC;


-- T3.4: Revenue by marital status
SELECT
    MaritalStatus,
    COUNT(*)                                    AS customers,
    ROUND(SUM(CashbackAmount), 2)               AS total_cashback,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY MaritalStatus
ORDER BY total_cashback DESC;


-- T3.5: Revenue by payment mode
SELECT
    PreferredPaymentMode,
    COUNT(*)                                    AS customers,
    ROUND(SUM(CashbackAmount), 2)               AS total_cashback,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY PreferredPaymentMode
ORDER BY total_cashback DESC;


-- T3.6: Top 20 highest-value churned customers (revenue lost)
SELECT
    CustomerID,
    ROUND(CashbackAmount, 2)                    AS cashback,
    OrderCount,
    ROUND(CashbackAmount * OrderCount, 2)       AS estimated_ltv,
    Tenure, MaritalStatus, PreferedOrderCat,
    SatisfactionScore, Complain
FROM customers
WHERE Churn = 1 AND CashbackAmount >= 200
ORDER BY estimated_ltv DESC
LIMIT 20;


-- T3.7: Revenue still at risk from active customers
SELECT
    CustomerID,
    ROUND(CashbackAmount, 2)                    AS cashback,
    OrderCount,
    ROUND(CashbackAmount * OrderCount, 2)       AS estimated_ltv,
    SatisfactionScore, Complain, DaySinceLastOrder
FROM customers
WHERE Churn = 0
  AND Complain = 1
  AND SatisfactionScore <= 2
  AND CashbackAmount >= 200
ORDER BY estimated_ltv DESC
LIMIT 20;

--  MYSQL TASK 4 — CHURN RATE ANALYSIS
--  Overall: 16.84% | 948 out of 5,630 customers churned
--  #1 driver: Complaint → 31.67% churn vs 10.93% without

-- T4.1: Overall churn summary
SELECT
    COUNT(*)                                    AS total_customers,
    SUM(Churn)                                  AS total_churned,
    COUNT(*) - SUM(Churn)                       AS total_retained,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND((COUNT(*)-SUM(Churn))/COUNT(*)*100,2) AS retention_rate_pct,
    ROUND(AVG(CASE WHEN Churn=1 THEN CashbackAmount END), 2)
                                                AS avg_cashback_churned,
    ROUND(AVG(CASE WHEN Churn=0 THEN CashbackAmount END), 2)
                                                AS avg_cashback_retained
FROM customers;
-- Expected: 5630 | 948 | 4682 | 16.84% | 83.16%


-- T4.2: Churn by complaint status (single biggest driver)
SELECT
    CASE Complain WHEN 1 THEN 'Has Complaint'
                  ELSE        'No Complaint' END AS complaint_status,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback
FROM customers
GROUP BY Complain
ORDER BY churn_rate_pct DESC;
-- Result: Has Complaint=31.67% | No Complaint=10.93% (3x difference!)


-- T4.3: Churn by tenure band
SELECT
    CASE
        WHEN Tenure <= 1  THEN '1. New         (0-1 months)'
        WHEN Tenure <= 6  THEN '2. Early       (2-6 months)'
        WHEN Tenure <= 12 THEN '3. Growing     (7-12 months)'
        WHEN Tenure <= 24 THEN '4. Established (1-2 years)'
        ELSE                   '5. Loyal       (2+ years)'
    END                                         AS tenure_band,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback
FROM customers
GROUP BY tenure_band
ORDER BY tenure_band;
-- Key: New (0-1 month) = 51.84% churn | Loyal (2+ yrs) = 0.00% churn


-- T4.4: Churn by marital status
SELECT
    MaritalStatus,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(OrderCount), 2)                   AS avg_orders
FROM customers
GROUP BY MaritalStatus
ORDER BY churn_rate_pct DESC;
-- Result: Single=26.73% | Divorced=14.62% | Married=11.52%


-- T4.5: Churn by payment mode
SELECT
    PreferredPaymentMode,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY PreferredPaymentMode
ORDER BY churn_rate_pct DESC;
-- Result: COD=24.90% | E wallet=22.80% | UPI=17.39%


-- T4.6: Churn by order category
SELECT
    PreferedOrderCat                            AS order_category,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback
FROM customers
GROUP BY PreferedOrderCat
ORDER BY churn_rate_pct DESC;
-- Result: Mobile Phone=27.40% | Fashion=15.50% | Grocery=4.88%


-- T4.7: Churn by satisfaction score
SELECT
    SatisfactionScore,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY SatisfactionScore
ORDER BY SatisfactionScore;
-- Surprise: Score 5 = 23.83% churn (HIGHEST!) - not just unhappy customers leaving


-- T4.8: Churn by city tier
SELECT
    CityTier,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback
FROM customers
GROUP BY CityTier
ORDER BY churn_rate_pct DESC;
-- Result: Tier 3=21.37% | Tier 2=19.83% | Tier 1=14.51%


-- T4.9: Churn by gender
SELECT
    Gender,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback
FROM customers
GROUP BY Gender
ORDER BY churn_rate_pct DESC;
-- Result: Male=17.73% | Female=15.49% 

-- T4.10: Combined — complaint + marital status (highest risk group)
SELECT
    MaritalStatus,
    CASE Complain WHEN 1 THEN 'Has Complaint'
                  ELSE        'No Complaint' END AS complaint_status,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS churned,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY MaritalStatus, Complain
ORDER BY churn_rate_pct DESC;
-- Single + Has Complaint = HIGHEST risk combination in entire dataset

--  ADVANCED TASK 1 — BUILD CUSTOMER RETENTION STRATEGY

-- AT1.1: New customer drop-off by month (onboarding window)
SELECT
    CASE
        WHEN Tenure = 0 THEN 'Month 0 — Just Joined'
        WHEN Tenure = 1 THEN 'Month 1'
        WHEN Tenure = 2 THEN 'Month 2'
        WHEN Tenure = 3 THEN 'Month 3'
        ELSE                 'Month 4+'
    END                                         AS onboarding_stage,
    COUNT(*)                                    AS customers,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(OrderCount), 2)                   AS avg_orders,
    ROUND(AVG(HourSpendOnApp), 2)               AS avg_app_hours
FROM customers
WHERE Tenure <= 4
GROUP BY onboarding_stage
ORDER BY onboarding_stage;
-- Key: Month 0 = 53.54% churn — onboarding is #1 retention priority


-- AT1.2: Complaint volume by tenure group
SELECT
    CASE
        WHEN Tenure <= 6  THEN '1. New (0-6 months)'
        WHEN Tenure <= 24 THEN '2. Growing (7-24 months)'
        ELSE                   '3. Loyal (2+ years)'
    END                                         AS tenure_group,
    COUNT(*)                                    AS customers,
    SUM(Complain)                               AS total_complaints,
    ROUND(SUM(Complain)/COUNT(*)*100, 2)        AS complaint_rate_pct,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY tenure_group
ORDER BY churn_rate_pct DESC;


-- AT1.3: COD to digital payment migration opportunity
SELECT
    CASE WHEN PreferredPaymentMode = 'COD' THEN 'COD (Cash)'
         ELSE 'Digital Payment'
    END                                         AS payment_type,
    COUNT(*)                                    AS customers,
    ROUND(AVG(Tenure), 1)                       AS avg_tenure,
    ROUND(AVG(OrderCount), 2)                   AS avg_orders,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct
FROM customers
GROUP BY payment_type
ORDER BY churn_rate_pct DESC;
-- COD = 24.90% churn vs Digital = lower → migrate COD users


-- AT1.4: Mobile Phone post-purchase retention opportunity
SELECT
    PreferedOrderCat,
    COUNT(*)                                    AS customers,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(OrderCount), 2)                   AS avg_repeat_orders
FROM customers
GROUP BY PreferedOrderCat
ORDER BY churn_rate_pct DESC;
-- Mobile Phone = 27.40% churn → needs post-purchase follow-up

--  ADVANCED TASK 2 — LOYALTY PROGRAM RECOMMENDATIONS

-- AT2.1: Champion customers — VIP tier (reward and retain)
SELECT
    CustomerID, OrderCount, Tenure,
    ROUND(CashbackAmount, 2)                    AS cashback,
    MaritalStatus, PreferedOrderCat,
    PreferredPaymentMode, SatisfactionScore
FROM customers
WHERE OrderCount >= 4
  AND CashbackAmount >= 200
  AND Churn = 0
ORDER BY CashbackAmount DESC
LIMIT 20;
-- 423 champion customers → recommend: VIP exclusive discounts, early access


-- AT2.2: Loyalty tier assignment for all active customers
SELECT
    CASE
        WHEN OrderCount >= 4 AND CashbackAmount >= 200 THEN '1. Champion  — VIP rewards'
        WHEN OrderCount >= 4 AND CashbackAmount >= 150 THEN '2. Loyal     — bonus cashback'
        WHEN OrderCount >= 2 AND CashbackAmount >= 150 THEN '3. Growing   — milestone rewards'
        WHEN Tenure >= 12                              THEN '4. Long-Term — anniversary offers'
        WHEN Tenure <= 3 AND OrderCount <= 1           THEN '6. New&Risky — onboarding care'
        ELSE                                                '5. Regular   — standard program'
    END                                         AS loyalty_tier,
    COUNT(*)                                    AS customers,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(OrderCount), 2)                   AS avg_orders,
    ROUND(AVG(Tenure), 1)                       AS avg_tenure_months
FROM customers
GROUP BY loyalty_tier
ORDER BY loyalty_tier;


-- AT2.3: Single new customers — Solo Shopper loyalty program target
SELECT
    MaritalStatus,
    CASE WHEN Tenure <= 6 THEN 'New (0-6 months)'
         ELSE 'Established (6+ months)' END     AS tenure_group,
    COUNT(*)                                    AS customers,
    ROUND(AVG(Churn)*100, 2)                    AS churn_rate_pct,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(OrderCount), 2)                   AS avg_orders
FROM customers
WHERE MaritalStatus = 'Single'
GROUP BY MaritalStatus, tenure_group
ORDER BY churn_rate_pct DESC;
-- 811 single new customers → recommend: Solo Shopper loyalty tier


-- AT2.4: COD users — cashback incentive to switch to digital
SELECT
    CustomerID, Tenure, OrderCount,
    ROUND(CashbackAmount, 2)                    AS cashback,
    MaritalStatus, CityTier, SatisfactionScore
FROM customers
WHERE PreferredPaymentMode = 'COD'
  AND Churn = 0
  AND OrderCount >= 2
  AND Tenure >= 3
ORDER BY CashbackAmount DESC
LIMIT 25;
-- 386 COD users → offer +5% cashback for switching to digital payment

--  ADVANCED TASK 3 — IDENTIFY HIGH-VALUE AT-RISK CUSTOMERS
--  422 active customers with complaints + low satisfaction
--  Total cashback value at risk: $78,107

-- AT3.1: Full at-risk customer list with urgency label
SELECT
    CustomerID,
    ROUND(CashbackAmount, 2)                    AS cashback,
    OrderCount,
    ROUND(CashbackAmount * OrderCount, 2)       AS estimated_ltv,
    Tenure,
    SatisfactionScore,
    Complain,
    DaySinceLastOrder,
    MaritalStatus,
    PreferedOrderCat,
    PreferredPaymentMode,
    CASE
        WHEN Complain=1 AND SatisfactionScore<=2 AND DaySinceLastOrder>=10
            THEN 'CRITICAL — Act Immediately'
        WHEN Complain=1 AND SatisfactionScore<=2
            THEN 'HIGH — Urgent Outreach'
        WHEN Complain=1 OR SatisfactionScore<=2
            THEN 'MEDIUM — Monitor Closely'
        ELSE 'LOW'
    END                                         AS urgency_level
FROM customers
WHERE Churn = 0
  AND (Complain = 1 OR SatisfactionScore <= 2)
ORDER BY estimated_ltv DESC
LIMIT 30;


-- AT3.2: Revenue at risk summary
SELECT
    COUNT(*)                                    AS at_risk_customers,
    ROUND(SUM(CashbackAmount), 2)               AS total_revenue_at_risk,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    SUM(CASE WHEN Complain=1 AND SatisfactionScore<=2 AND DaySinceLastOrder>=10
             THEN 1 ELSE 0 END)                 AS critical_count,
    SUM(CASE WHEN Complain=1 AND SatisfactionScore<=2
             THEN 1 ELSE 0 END)                 AS high_risk_count
FROM customers
WHERE Churn = 0 AND Complain = 1 AND SatisfactionScore <= 2;
-- 422 customers | $78,107 at risk


-- AT3.3: At-risk by city (where to focus retention teams)
SELECT
    CityTier,
    COUNT(*)                                    AS at_risk_customers,
    ROUND(SUM(CashbackAmount), 2)               AS revenue_at_risk,
    ROUND(AVG(CashbackAmount), 2)               AS avg_cashback,
    ROUND(AVG(Tenure), 1)                       AS avg_tenure
FROM customers
WHERE Churn = 0 AND Complain = 1 AND SatisfactionScore <= 2
GROUP BY CityTier
ORDER BY revenue_at_risk DESC;


-- AT3.4: Silent at-risk customers (not ordered in 10+ days)
SELECT
    CustomerID,
    ROUND(CashbackAmount, 2)                    AS cashback,
    DaySinceLastOrder,
    OrderCount, Tenure, Complain,
    SatisfactionScore, MaritalStatus, PreferedOrderCat
FROM customers
WHERE Churn = 0
  AND DaySinceLastOrder >= 10
  AND Complain = 1
ORDER BY DaySinceLastOrder DESC, CashbackAmount DESC
LIMIT 25;
-- These customers are going silent — call/email outreach needed today

--  ADVANCED TASK 4 — CHURN PROBABILITY SCORING MODEL
--  5-factor rule-based model | validated on actual churn data
--  High Risk = 49.90% actual churn | Low Risk = 6.98% actual churn

-- AT4.1: Score all customers and assign risk tier
SELECT
    CustomerID,
    Churn                                       AS actual_churn,
    Tenure,
    SatisfactionScore,
    Complain,
    DaySinceLastOrder,
    OrderCount,
    ROUND(CashbackAmount, 2)                    AS cashback,
    MaritalStatus,
    PreferedOrderCat,

    -- CHURN SCORE (0 to 10 points)
    (
        CASE WHEN Complain = 1              THEN 3 ELSE 0 END +
        CASE WHEN SatisfactionScore >= 4    THEN 2 ELSE 0 END +
        CASE WHEN Tenure <= 3               THEN 2 ELSE 0 END +
        CASE WHEN DaySinceLastOrder >= 10   THEN 2 ELSE 0 END +
        CASE WHEN OrderCount <= 1           THEN 1 ELSE 0 END
    )                                           AS churn_score,

    -- RISK TIER
    CASE
        WHEN (
            CASE WHEN Complain=1            THEN 3 ELSE 0 END +
            CASE WHEN SatisfactionScore>=4  THEN 2 ELSE 0 END +
            CASE WHEN Tenure<=3             THEN 2 ELSE 0 END +
            CASE WHEN DaySinceLastOrder>=10 THEN 2 ELSE 0 END +
            CASE WHEN OrderCount<=1         THEN 1 ELSE 0 END
        ) >= 6 THEN 'HIGH RISK   (Score 6-10)'
        WHEN (
            CASE WHEN Complain=1            THEN 3 ELSE 0 END +
            CASE WHEN SatisfactionScore>=4  THEN 2 ELSE 0 END +
            CASE WHEN Tenure<=3             THEN 2 ELSE 0 END +
            CASE WHEN DaySinceLastOrder>=10 THEN 2 ELSE 0 END +
            CASE WHEN OrderCount<=1         THEN 1 ELSE 0 END
        ) >= 3 THEN 'MEDIUM RISK (Score 3-5)'
        ELSE        'LOW RISK    (Score 0-2)'
    END                                         AS risk_tier

FROM customers
ORDER BY churn_score DESC, CashbackAmount DESC
LIMIT 50;


-- AT4.2: Model validation — actual churn rate per risk tier
SELECT
    CASE
        WHEN (
            CASE WHEN Complain=1            THEN 3 ELSE 0 END +
            CASE WHEN SatisfactionScore>=4  THEN 2 ELSE 0 END +
            CASE WHEN Tenure<=3             THEN 2 ELSE 0 END +
            CASE WHEN DaySinceLastOrder>=10 THEN 2 ELSE 0 END +
            CASE WHEN OrderCount<=1         THEN 1 ELSE 0 END
        ) >= 6 THEN 'HIGH RISK'
        WHEN (
            CASE WHEN Complain=1            THEN 3 ELSE 0 END +
            CASE WHEN SatisfactionScore>=4  THEN 2 ELSE 0 END +
            CASE WHEN Tenure<=3             THEN 2 ELSE 0 END +
            CASE WHEN DaySinceLastOrder>=10 THEN 2 ELSE 0 END +
            CASE WHEN OrderCount<=1         THEN 1 ELSE 0 END
        ) >= 3 THEN 'MEDIUM RISK'
        ELSE        'LOW RISK'
    END                                         AS risk_tier,
    COUNT(*)                                    AS customers,
    SUM(Churn)                                  AS actual_churned,
    ROUND(AVG(Churn)*100, 2)                    AS actual_churn_rate_pct
FROM customers
GROUP BY risk_tier
ORDER BY actual_churn_rate_pct DESC;
-- HIGH RISK = 49.90% actual churn ✓
-- MEDIUM RISK = 22.45% actual churn ✓
-- LOW RISK = 6.98% actual churn ✓
-- Model separates high-risk from low-risk by 6x — model is valid

-- AT4.3: What drives each score point (factor validation)
SELECT churn_factor, customers_flagged, actual_churn_pct FROM (
SELECT 'Complain=1 (3 pts — biggest driver)'       AS churn_factor,
    SUM(Complain)                                   AS customers_flagged,
    ROUND(AVG(CASE WHEN Complain=1 THEN Churn END)*100, 2) AS actual_churn_pct
FROM customers
UNION ALL
SELECT 'SatisfactionScore>=4 (2 pts)',
    SUM(CASE WHEN SatisfactionScore>=4 THEN 1 ELSE 0 END),
    ROUND(AVG(CASE WHEN SatisfactionScore>=4 THEN Churn END)*100, 2)
FROM customers
UNION ALL
SELECT 'Tenure<=3 months (2 pts)',
    SUM(CASE WHEN Tenure<=3 THEN 1 ELSE 0 END),
    ROUND(AVG(CASE WHEN Tenure<=3 THEN Churn END)*100, 2)
FROM customers
UNION ALL
SELECT 'DaySinceLastOrder>=10 (2 pts)',
    SUM(CASE WHEN DaySinceLastOrder>=10 THEN 1 ELSE 0 END),
    ROUND(AVG(CASE WHEN DaySinceLastOrder>=10 THEN Churn END)*100, 2)
FROM customers
UNION ALL
SELECT 'OrderCount<=1 (1 pt)',
    SUM(CASE WHEN OrderCount<=1 THEN 1 ELSE 0 END),
    ROUND(AVG(CASE WHEN OrderCount<=1 THEN Churn END)*100, 2)
FROM customers
) AS factor_table
ORDER BY actual_churn_pct DESC;

--  BUSINESS INSIGHTS SUMMARY — ALL KPIs IN ONE QUERY

SELECT 'Total Customers'                AS insight, CAST(COUNT(*) AS CHAR) AS value
FROM customers
UNION ALL
SELECT 'Churned Customers',              CAST(SUM(Churn) AS CHAR)          FROM customers
UNION ALL
SELECT 'Overall Churn Rate %',           CAST(ROUND(AVG(Churn)*100,2) AS CHAR) FROM customers
UNION ALL
SELECT 'Repeat Customers (OrderCount>1)',CAST(SUM(CASE WHEN OrderCount>1 THEN 1 ELSE 0 END) AS CHAR) FROM customers
UNION ALL
SELECT 'One-Time Customers',             CAST(SUM(CASE WHEN OrderCount=1 THEN 1 ELSE 0 END) AS CHAR) FROM customers
UNION ALL
SELECT 'Complaint Churn Rate %',         CAST(ROUND(AVG(CASE WHEN Complain=1 THEN Churn END)*100,2) AS CHAR) FROM customers
UNION ALL
SELECT 'No Complaint Churn Rate %',      CAST(ROUND(AVG(CASE WHEN Complain=0 THEN Churn END)*100,2) AS CHAR) FROM customers
UNION ALL
SELECT 'New Customer Churn % (0-1 mo)',  CAST(ROUND(AVG(CASE WHEN Tenure<=1 THEN Churn END)*100,2) AS CHAR) FROM customers
UNION ALL
SELECT 'Loyal Customer Churn % (2+ yr)', CAST(ROUND(AVG(CASE WHEN Tenure>=24 THEN Churn END)*100,2) AS CHAR) FROM customers
UNION ALL
SELECT 'Mobile Phone Category Churn %',  CAST(ROUND(AVG(CASE WHEN PreferedOrderCat='Mobile Phone' THEN Churn END)*100,2) AS CHAR) FROM customers
UNION ALL
SELECT 'Grocery Category Churn %',       CAST(ROUND(AVG(CASE WHEN PreferedOrderCat='Grocery' THEN Churn END)*100,2) AS CHAR) FROM customers
UNION ALL
SELECT 'COD Payment Churn %',            CAST(ROUND(AVG(CASE WHEN PreferredPaymentMode='COD' THEN Churn END)*100,2) AS CHAR) FROM customers
UNION ALL
SELECT 'Single Marital Status Churn %',  CAST(ROUND(AVG(CASE WHEN MaritalStatus='Single' THEN Churn END)*100,2) AS CHAR) FROM customers
UNION ALL
SELECT 'High-Value At-Risk Customers',   CAST(SUM(CASE WHEN Churn=0 AND Complain=1 AND SatisfactionScore<=2 THEN 1 END) AS CHAR) FROM customers
UNION ALL
SELECT 'Revenue At Risk ($)',            CAST(ROUND(SUM(CASE WHEN Churn=0 AND Complain=1 AND SatisfactionScore<=2 THEN CashbackAmount END),2) AS CHAR) FROM customers
UNION ALL
SELECT 'Champion Customers',             CAST(SUM(CASE WHEN OrderCount>=4 AND CashbackAmount>=200 AND Churn=0 THEN 1 END) AS CHAR) FROM customers
UNION ALL
SELECT 'High Risk Tier Customers',       CAST(SUM(CASE WHEN (CASE WHEN Complain=1 THEN 3 ELSE 0 END + CASE WHEN SatisfactionScore>=4 THEN 2 ELSE 0 END + CASE WHEN Tenure<=3 THEN 2 ELSE 0 END + CASE WHEN DaySinceLastOrder>=10 THEN 2 ELSE 0 END + CASE WHEN OrderCount<=1 THEN 1 ELSE 0 END)>=6 THEN 1 ELSE 0 END) AS CHAR) FROM customers;
