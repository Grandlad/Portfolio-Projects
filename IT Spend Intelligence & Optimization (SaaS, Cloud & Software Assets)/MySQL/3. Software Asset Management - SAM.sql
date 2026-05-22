-- 3. Software Asset Management

-- 3.1. Verification of unused licenses (Shelfware)
-- Goal: Verification of purchased licenses vs licenses in use - Negotiation to decrease number of licenses/contract termination.

SELECT 
    sl.license_id,
    v.vendor_name,
    sl.product_name,
    sl.seats_purchased,
    sl.seats_used,
    (sl.seats_purchased - sl.seats_used) AS unused_seats,
    -- Checking unsused licenses Per-Seat (Cost)
    IF(sl.license_type = 'Per-Seat', (sl.seats_purchased - sl.seats_used) * sl.unit_price_monthly, 0) AS monthly_wasted_cost,
    sl.annual_cost,
    sl.renewal_date
FROM software_licenses sl
JOIN vendors v ON sl.vendor_id = v.vendor_id
WHERE sl.is_active = 1
  AND sl.seats_purchased > sl.seats_used
ORDER BY monthly_wasted_cost DESC, unused_seats DESC
;

-- 3.2. Elimination of duplicates and consolidation of vendors
-- Goal: Verification of products with the same category, but from different vendors. - Negotiation point for volumes

SELECT 
    sl1.category AS license_category,
    sl1.product_name AS product_a,
    v1.vendor_name AS vendor_a,
    sl1.annual_cost AS annual_cost_a,
    sl2.product_name AS product_b,
    v2.vendor_name AS vendor_b,
    sl2.annual_cost AS annual_cost_b,
    (sl1.annual_cost + sl2.annual_cost) AS total_combined_category_spend
FROM software_licenses sl1
JOIN software_licenses sl2 ON sl1.category = sl2.category AND sl1.license_id < sl2.license_id
JOIN vendors v1 ON sl1.vendor_id = v1.vendor_id
JOIN vendors v2 ON sl2.vendor_id = v2.vendor_id
WHERE sl1.is_active = 1 
  AND sl2.is_active = 1
  AND sl1.vendor_id <> sl2.vendor_id
ORDER BY total_combined_category_spend DESC
;

-- 3.3. Analysis of licenses with utilization < 50% (Historical Usage) (CTE)
-- Goal: First licenses to remove during agreement renewal.

WITH LatestSnapshot AS (
    SELECT 
        license_id,
        snapshot_date,
        seats_active,
        seats_purchased,
        utilization_pct,
        ROW_NUMBER() OVER (PARTITION BY license_id ORDER BY snapshot_date DESC) as rn
    FROM license_usage_log
)
SELECT 
    sl.license_id,
    v.vendor_name,
    sl.product_name,
    ls.snapshot_date AS last_log_date,
    ls.seats_purchased,
    ls.seats_active,
    ls.utilization_pct
FROM LatestSnapshot ls
JOIN software_licenses sl ON ls.license_id = sl.license_id
JOIN vendors v ON sl.vendor_id = v.vendor_id
WHERE ls.rn = 1 
  AND ls.utilization_pct < 50.00
  AND sl.is_active = 1
ORDER BY ls.utilization_pct ASC
;

-- 3.4. SAM Renewal Radar
-- Goal: Hunting down low-utilization licenses

WITH LatestSnapshot AS (
    SELECT 
        license_id,
        snapshot_date,
        seats_active,
        seats_purchased,
        utilization_pct,
        ROW_NUMBER() OVER (PARTITION BY license_id ORDER BY snapshot_date DESC) as rn
    FROM license_usage_log
)
SELECT 
    sl.license_id,
    v.vendor_name,
    sl.product_name,
    sl.renewal_date,
    ls.utilization_pct,
    sl.annual_cost,
    ROUND(sl.annual_cost * (1 - (ls.utilization_pct / 100)), 2) AS potential_annual_saving
FROM LatestSnapshot ls
JOIN software_licenses sl ON ls.license_id = sl.license_id
JOIN vendors v ON sl.vendor_id = v.vendor_id
WHERE ls.rn = 1 
  AND ls.utilization_pct < 50.00
  AND sl.is_active = 1
ORDER BY potential_annual_saving DESC
;