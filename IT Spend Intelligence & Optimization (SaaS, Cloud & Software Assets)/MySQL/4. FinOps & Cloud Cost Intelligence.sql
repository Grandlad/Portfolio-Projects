-- 4. FinOps & Cloud Cost Intelligence

-- 4.1. Commitment Tracking
-- Goal: Due to discounts basing on usage, assuming that we commit for annual/monthly spends,
-- we need to verify amounts for commitment and to see if we over paying for something or we overreach the contract

SELECT 
    c.contract_id,
    c.contract_name,
    v.vendor_name,
    cc.department_name,
    c.annual_value AS committed_annual_amount,
    -- Summing up all invoices connected to the contract and Cloud Services categorie
    COALESCE(SUM(i.amount_gross), 0) AS actual_spent_so_far,
    -- Calculating difference
    (c.annual_value - COALESCE(SUM(i.amount_gross), 0)) AS commitment_balance,
    -- Status of commitment
    CASE 
        WHEN COALESCE(SUM(i.amount_gross), 0) >= c.annual_value THEN 'Commitment fulfilled (Possible On-Demand)'
        ELSE 'In Progress (Risk of underspending the budget)'
    END AS commitment_status
FROM contracts c
JOIN vendors v ON c.vendor_id = v.vendor_id
JOIN cost_centers cc ON c.cost_center_id = cc.cost_center_id
LEFT JOIN invoices i ON c.contract_id = i.contract_id 
    AND i.category = 'Cloud Services' 
    AND i.status = 'Paid'
WHERE c.contract_type = 'Cloud Commitment' 
  AND c.status = 'Active'
GROUP BY c.contract_id, c.contract_name, v.vendor_name, cc.department_name, c.annual_value
;

-- 4.2. Burn Rate & EOY Forecast
-- 

WITH CloudMonthlySpend AS (
    SELECT 
        cost_center_id,
        -- Calculating average monthly cost basing on Cloud Services Invoices from current yeart
        AVG(amount_gross) AS avg_monthly_spend,
        SUM(amount_gross) AS total_spent_ytd,
        -- Verifying unique months with paymants this year
        COUNT(DISTINCT EXTRACT(YEAR_MONTH FROM invoice_date)) AS months_invoiced
    FROM invoices
    WHERE category = 'Cloud Services'
      AND EXTRACT(YEAR FROM invoice_date) = EXTRACT(YEAR FROM CURDATE())
    GROUP BY cost_center_id
)
SELECT 
    cc.department_name,
    cc.budget_owner,
    cc.annual_budget AS total_department_annual_budget,
    ROUND(cms.total_spent_ytd, 2) AS cloud_spent_ytd,
    ROUND(cms.avg_monthly_spend, 2) AS current_monthly_burn_rate,
    -- Forecasting cost by EOY: (avg cost * remaining months) + Spend already invoiced
    ROUND(
        cms.total_spent_ytd + (cms.avg_monthly_spend * (12 - cms.months_invoiced)), 
        2
    ) AS estimated_end_of_year_cost,
    -- Verifying if forecasted cost of Cloud Services will overreach yearly budget 
    CASE 
        WHEN (cms.total_spent_ytd + (cms.avg_monthly_spend * (12 - cms.months_invoiced))) > cc.annual_budget 
        THEN '⚠️ ALARM: Overspend!'
        ELSE '✅ In Budget'
    END AS budget_alert_status
FROM CloudMonthlySpend cms
JOIN cost_centers cc ON cms.cost_center_id = cc.cost_center_id
WHERE cc.is_active = 1
;

-- 4.3. FinOps Untaggeds Costs Audit
-- Goal: Hunting down invoices from 'Cloud Services' or 'Software License', which are not connected to any contract or ich Cost Center is Unnkown/Inactive

SELECT 
    i.invoice_id,
    i.invoice_number,
    v.vendor_name,
    i.invoice_date,
    i.amount_gross,
    i.currency,
    i.category,
    i.description,
    -- Verification, if connected cost center is active
    cc.department_name AS assigned_department,
    cc.is_active AS is_department_active
FROM invoices i
JOIN vendors v ON i.vendor_id = v.vendor_id
LEFT JOIN cost_centers cc ON i.cost_center_id = cc.cost_center_id
WHERE (i.category IN ('Cloud Services', 'Software License') OR i.description LIKE '%cloud%' OR i.description LIKE '%aws%' OR i.description LIKE '%azure%')
  AND (
      i.contract_id IS NULL 
      OR i.cost_center_id IS NULL 
      OR cc.is_active = 0
  )
ORDER BY i.amount_gross DESC
;



