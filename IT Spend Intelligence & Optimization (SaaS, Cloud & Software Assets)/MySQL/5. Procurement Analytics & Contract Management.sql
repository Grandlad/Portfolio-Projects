-- 5. Procurement Analytics & Contract Management

-- 5.1. Notice Period & Termination Radar
-- Goal: Auto-renewal prevention


SELECT 
    c.contract_id,
    c.contract_name,
    v.vendor_name,
    c.end_date,
    c.notice_period_days,
    -- Calculating last day, when documents needs to be delivered to the vendor.
    DATE_SUB(c.end_date, INTERVAL c.notice_period_days DAY) AS notice_deadline_date,
    -- Calculating number of days (Assuming year 2026) 
    DATEDIFF(DATE_SUB(c.end_date, INTERVAL c.notice_period_days DAY), CURDATE()) AS days_left_to_act,
    c.annual_value,
    c.auto_renewal,
    cc.budget_owner
FROM contracts c
JOIN vendors v ON c.vendor_id = v.vendor_id
JOIN cost_centers cc ON c.cost_center_id = cc.cost_center_id
WHERE c.status = 'Active'
  AND c.end_date >= CURDATE()
ORDER BY days_left_to_act ASC
;

-- 5.2. Vendor Spend Concentration
-- Goal: Identifications of Vendor Lock-Ins and verification of situations where we overspend vendors without status preferred.

WITH TotalITSpend AS (
    SELECT SUM(amount_gross) AS total_spend FROM invoices WHERE status = 'Paid'
)
SELECT 
    v.vendor_id,
    v.vendor_name,
    v.category AS vendor_category,
    v.preferred AS is_preferred_vendor,
    ROUND(SUM(i.amount_gross), 2) AS total_spent_with_vendor,
    -- Counting % contribution in whole IT budget
    ROUND((SUM(i.amount_gross) / (SELECT total_spend FROM TotalITSpend)) * 100, 2) AS share_of_total_it_spend,
    COUNT(i.invoice_id) AS total_invoices_count
FROM vendors v
JOIN invoices i ON v.vendor_id = i.vendor_id
WHERE i.status = 'Paid'
GROUP BY v.vendor_id, v.vendor_name, v.category, v.preferred
ORDER BY total_spent_with_vendor DESC
;

-- 5.3. Cashflow & Payment Terms Alignment

SELECT 
    v.vendor_name,
    i.invoice_number,
    i.invoice_date,
    i.due_date,
    i.paid_date,
    v.payment_terms_days AS official_terms_days,
    -- How many days passed since invoice_date to paid_date 
    DATEDIFF(i.paid_date, i.invoice_date) AS real_days_to_pay,
    -- How many days we are late with payment 
    DATEDIFF(i.paid_date, i.due_date) AS days_overdue,
    i.amount_gross,
    -- Payment Cashflow Analysis
    CASE 
        WHEN DATEDIFF(i.paid_date, i.due_date) > 0 THEN '⚠️ Delayed Payment (Risk of penalty)'
        WHEN DATEDIFF(i.paid_date, i.invoice_date) < (v.payment_terms_days - 10) THEN '💵 Fast Payment (Cash Freezing)'
        ELSE '✅ Optimal Cashflow'
    END AS cash_flow_efficiency
FROM invoices i
JOIN vendors v ON i.vendor_id = v.vendor_id
WHERE i.status = 'Paid' 
  AND i.paid_date IS NOT NULL
  -- Analysis only on what has happened until Current date 
  AND i.paid_date <= CURDATE() 
ORDER BY days_overdue DESC, real_days_to_pay ASC
;