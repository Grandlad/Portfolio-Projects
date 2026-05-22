-- 0. EDA

USE it_spend;

SELECT 'cost_centers'      AS tabela, COUNT(*) AS wiersze FROM cost_centers
UNION ALL SELECT 'vendors',            COUNT(*) FROM vendors
UNION ALL SELECT 'contracts',          COUNT(*) FROM contracts
UNION ALL SELECT 'employees',          COUNT(*) FROM employees
UNION ALL SELECT 'software_licenses',  COUNT(*) FROM software_licenses
UNION ALL SELECT 'hardware_assets',    COUNT(*) FROM hardware_assets
UNION ALL SELECT 'invoices',           COUNT(*) FROM invoices
UNION ALL SELECT 'license_usage_log',  COUNT(*) FROM license_usage_log;

-- 0.1. Verification od data scale and compatibility
-- Verification overall number of records and sum of spend

SELECT 
    COUNT(*) AS total_invoices,
    SUM(amount_gross) AS total_spend_gross,
    AVG(amount_gross) AS avg_invoice_value,
    MIN(invoice_date) AS data_from,
    MAX(invoice_date) AS data_to
FROM invoices;

-- 0.2. Vendor Analysis
-- Top 15 Vendors by Spend

SELECT 
    v.vendor_name, 
    v.category,
    COUNT(i.invoice_id) AS invoice_count,
    SUM(i.amount_gross) AS total_spend
FROM vendors v
JOIN invoices i ON v.vendor_id = i.vendor_id
GROUP BY v.vendor_name, v.category
ORDER BY total_spend DESC
LIMIT 15;

-- 0.3. Deep Dive in Software (SAM - Licenses)
-- License Utilization Analysis (Unused Resources)

SELECT 
    sl.product_name,
    sl.seats_purchased,
    ROUND(AVG(log.seats_active), 0) AS avg_active_seats,
    sl.seats_purchased - MIN(log.seats_active) AS max_unused_seats,
    ROUND((AVG(log.seats_active) / sl.seats_purchased) * 100, 2) AS utilization_pct
FROM software_licenses sl
JOIN license_usage_log log ON sl.license_id = log.license_id
GROUP BY sl.license_id, sl.product_name, sl.seats_purchased
HAVING utilization_pct < 80 
ORDER BY utilization_pct ASC;

-- 0.4. Hardware Analysis (HAM)
-- Verification of "Out of Warranty" Products

SELECT 
    model, 
    asset_tag, 
    warranty_expiry,
    CASE 
        WHEN warranty_expiry < CURDATE() THEN 'Risk: Out of Warranty'
        WHEN warranty_expiry BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 90 DAY) THEN 'Expiring Soon'
        ELSE 'Protected'
    END AS warranty_status
FROM hardware_assets
WHERE is_active = 1
ORDER BY warranty_expiry ASC;


-- 0.5. Additional query: Data Quality
-- Verification if categories on invcoices are compatible with categories in invoices

SELECT 
    i.category AS invoice_cat, 
    v.category AS vendor_cat, 
    COUNT(*) as record_count
FROM invoices i
JOIN vendors v ON i.vendor_id = v.vendor_id
GROUP BY i.category, v.category;

-- 0.6. Warranty dates update (HAM) - Project needs
-- updating dates to match current year

UPDATE hardware_assets
SET 
    warranty_expiry = DATE_ADD(warranty_expiry, INTERVAL 5 YEAR),
    purchase_date = DATE_ADD(purchase_date, INTERVAL 5 YEAR),
    end_of_life_date = DATE_ADD(end_of_life_date, INTERVAL 5 YEAR);

-- 0.7. Software and Contracts Update (SAM) - Project needs

-- Contracts Update
UPDATE contracts
SET 
    start_date = DATE_ADD(start_date, INTERVAL 5 YEAR),
    end_date = DATE_ADD(end_date, INTERVAL 5 YEAR);

-- Licenses Update
UPDATE software_licenses
SET 
    purchase_date = DATE_ADD(purchase_date, INTERVAL 5 YEAR),
    renewal_date = DATE_ADD(renewal_date, INTERVAL 5 YEAR);

-- Logs Updaes (snapshots from "today")
UPDATE license_usage_log
SET 
    snapshot_date = DATE_ADD(snapshot_date, INTERVAL 5 YEAR);
    
-- Invoices Update
UPDATE invoices
SET 
    invoice_date = DATE_ADD(invoice_date, INTERVAL 5 YEAR),
    due_date = DATE_ADD(due_date, INTERVAL 5 YEAR),
    paid_date = DATE_ADD(paid_date, INTERVAL 5 YEAR);
