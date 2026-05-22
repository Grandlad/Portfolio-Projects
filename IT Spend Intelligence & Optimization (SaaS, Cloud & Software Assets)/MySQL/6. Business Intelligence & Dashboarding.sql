-- 6. Business Intelligence & Dashboarding

-- 6.1. Report Budget vs Actual

SELECT 
    cc.cost_center_id,
    cc.department_name,
    cc.budget_owner,
    cc.annual_budget,
    -- Summing up only paid and awaiting invoices from current year (2026) 
    COALESCE(SUM(CASE WHEN i.status IN ('Paid', 'Pending') THEN i.amount_gross END), 0) AS actual_spend_ytd,
    -- Counting budget left
    (cc.annual_budget - COALESCE(SUM(CASE WHEN i.status IN ('Paid', 'Pending') THEN i.amount_gross END), 0)) AS remaining_budget,
    -- % of budget spend
    ROUND(
        (COALESCE(SUM(CASE WHEN i.status IN ('Paid', 'Pending') THEN i.amount_gross END), 0) / cc.annual_budget) * 100, 
        2
    ) AS budget_utilization_pct
FROM cost_centers cc
LEFT JOIN invoices i ON cc.cost_center_id = i.cost_center_id 
    AND EXTRACT(YEAR FROM i.invoice_date) = EXTRACT(YEAR FROM CURDATE())
WHERE cc.is_active = 1
GROUP BY cc.cost_center_id, cc.department_name, cc.budget_owner, cc.annual_budget
ORDER BY budget_utilization_pct DESC
;

-- 6.2. Vendor Scorecard

SELECT 
    v.vendor_id,
    v.vendor_name,
    v.category,
    v.credit_score AS vendor_internal_credit_score,
    COUNT(i.invoice_id) AS total_invoices_handled,
    -- AVG delays in payments for this Vendor (in days) 
    ROUND(AVG(DATEDIFF(i.paid_date, i.due_date)), 1) AS avg_days_overdue,
    -- Count of delayed invoices
    SUM(CASE WHEN i.status = 'Disputed' THEN 1 ELSE 0 END) AS disputed_invoices_count,
    -- Assesing health of relationships based on delays and disputes
    CASE 
        WHEN SUM(CASE WHEN i.status = 'Disputed' THEN 1 ELSE 0 END) > 2 THEN '🔴 Risk (Disputes/Sanctions)'
        WHEN AVG(DATEDIFF(i.paid_date, i.due_date)) > 10 THEN '🟡 Attention (Often delays)'
        ELSE '🟢 Stable'
    END AS relationship_health_status
FROM vendors v
LEFT JOIN invoices i ON v.vendor_id = i.vendor_id
GROUP BY v.vendor_id, v.vendor_name, v.category, v.credit_score
ORDER BY v.credit_score DESC
;

-- 6.3. Savings Tracker

SELECT 
    'Software License Optimization' AS savings_source,
    COUNT(DISTINCT sl.license_id) AS optimized_items_count,
    -- Summing up wasted annual cost from licenses with utilization below 50%
    ROUND(SUM(sl.annual_cost * (1 - (lu.utilization_pct / 100))), 2) AS total_annual_savings_pln
FROM software_licenses sl
JOIN (
    SELECT license_id, utilization_pct,
           ROW_NUMBER() OVER (PARTITION BY license_id ORDER BY snapshot_date DESC) as rn
    FROM license_usage_log
) lu ON sl.license_id = lu.license_id AND lu.rn = 1
WHERE lu.utilization_pct < 50.00 AND sl.is_active = 1

UNION ALL

SELECT 
    'Hardware Asset Recovery (Offboarding)' AS savings_source,
    COUNT(ha.asset_id) AS optimized_items_count,
    -- estimating savings based on the current book value of the recovered equipment
    ROUND(SUM(ha.current_book_value), 2) AS total_annual_savings_pln
FROM hardware_assets ha
JOIN employees e ON ha.assigned_to_employee = e.employee_id
WHERE e.is_active = 0 AND ha.is_active = 1
;

-- CapEx Asset Dashboard

SELECT 
    cc.department_name,
    COUNT(ha.asset_id) AS total_active_assets,
    -- Starting CapEx value
    ROUND(SUM(ha.purchase_price), 2) AS total_historical_capex,
    -- Current market/book value of the entire fleet
    ROUND(SUM(ha.current_book_value), 2) AS total_current_book_value,
    -- Total depreciation
    ROUND(SUM(ha.purchase_price - ha.current_book_value), 2) AS total_depreciation_to_date,
    -- Spending Forecast: How much we need to spend to refurbish equipment that will reach End of Life in the next 365 days
    ROUND(
        SUM(CASE 
            WHEN ha.end_of_life_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 1 YEAR) 
            THEN ha.purchase_price 
            ELSE 0 
        END), 2
    ) AS next_12_months_refresh_cost_estimate
FROM hardware_assets ha
JOIN cost_centers cc ON ha.cost_center_id = cc.cost_center_id
WHERE ha.is_active = 1
GROUP BY cc.department_name
ORDER BY next_12_months_refresh_cost_estimate DESC
;
