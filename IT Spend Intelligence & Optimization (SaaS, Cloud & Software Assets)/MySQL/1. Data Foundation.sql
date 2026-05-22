-- 1. Data Foundation

-- 1.0. View Creation

CREATE OR REPLACE VIEW v_master_it_spend AS
SELECT 
    i.invoice_id,
    i.invoice_date,
    v.vendor_name,
    v.category AS vendor_category,
    cc.department_name,
    cc.budget_owner,
    i.amount_gross,
    i.currency,
    CASE 
        WHEN i.is_capex = 1 THEN 'Capital Expenditure (CapEx)'
        ELSE 'Operating Expenditure (OpEx)'
    END AS financial_type,
    i.status AS payment_status
FROM invoices i
JOIN vendors v ON i.vendor_id = v.vendor_id
JOIN cost_centers cc ON i.cost_center_id = cc.cost_center_id
;

SELECT *
FROM v_master_it_spend
;

-- 1.1. Data Normalization & Cleaning

-- Data Scrubbing

SELECT DISTINCT i.category AS invoice_cat, v.category AS vendor_cat
FROM invoices i
JOIN vendors v ON i.vendor_id = v.vendor_id
WHERE i.category != v.category
;

-- Unifying categories

CREATE OR REPLACE VIEW v_master_it_spend AS
SELECT 
    i.invoice_id,
    v.vendor_name,
    -- Cleaning Logic: If categories are different, we trust the invoice
    -- But to make sure we mark those as (Review Required)
    CASE 
        WHEN i.category = v.category THEN i.category
        ELSE CONCAT(i.category, ' (Review Required)') 
    END AS final_category,
    cc.department_name,
    i.amount_gross,
    i.is_capex
FROM invoices i
JOIN vendors v ON i.vendor_id = v.vendor_id
JOIN cost_centers cc ON i.cost_center_id = cc.cost_center_id
;

SELECT *
FROM v_master_it_spend
;

-- 1.2. Cost Taxonomy

-- A. Mapping Table

CREATE TABLE IF NOT EXISTS ref_tbm_taxonomy (
    invoice_category  VARCHAR(50) PRIMARY KEY,
    it_tower          VARCHAR(50), -- ex. Infrastructure, Applications, End User
    it_service        VARCHAR(50), -- ex. Compute, Storage, Helpdesk
    cost_type         VARCHAR(10)  -- ex. Run vs Grow 
)
;

-- Creating Categories (Inserting Data)

INSERT IGNORE INTO ref_tbm_taxonomy (invoice_category, it_tower, it_service, cost_type) VALUES
('Cloud Services',    'Infrastructure', 'Public Cloud', 'Run'),
('Software License',  'Applications',   'SaaS/Software', 'Run'),
('Hardware',          'End User',       'Client Computing', 'Grow'),
('Consulting',        'IT Management',  'Professional Services', 'Grow'),
('Telecom',           'Infrastructure', 'Network', 'Run'),
('Security',          'Security',       'Security Ops', 'Run')
;

SELECT *
FROM ref_tbm_taxonomy
;

-- B. Masterview


-- 1.3. Feeding with data (Maping 1:1 with categories from the invoices)

INSERT INTO ref_tbm_taxonomy (invoice_category, it_tower, it_service, cost_type) VALUES
('Cloud Services',    'Infrastructure', 'Public Cloud', 'Run'),
('Software License',  'Applications',   'SaaS/Software', 'Run'),
('Hardware',          'End User',       'Client Computing', 'Grow'),
('Consulting',        'IT Management',  'Professional Services', 'Grow'),
('Telecom',           'Infrastructure', 'Network', 'Run'),
('Security',          'Security',       'Security Ops', 'Run')
;

-- 1.4. Cleaning structure

DROP TABLE IF EXISTS ref_tbm_taxonomy
;

-- Master View

CREATE OR REPLACE VIEW v_final_spend_analysis AS
SELECT 
    i.invoice_id,
    i.invoice_date,
    v.vendor_name,
    TRIM(COALESCE(NULLIF(i.category, ''), NULLIF(v.category, ''))) AS raw_category,
    
    -- Hardcoding TBM Tower mapping - Directly on view
    CASE TRIM(COALESCE(NULLIF(i.category, ''), NULLIF(v.category, '')))
        WHEN 'Infrastructure' THEN 'Infrastructure'
        WHEN 'SaaS'           THEN 'Applications'
        WHEN 'Software'       THEN 'Applications'
        WHEN 'Hardware'       THEN 'End User'
        WHEN 'Consulting'     THEN 'IT Management'
        WHEN 'Support'        THEN 'IT Management'
        WHEN 'Telecom'        THEN 'Infrastructure'
        WHEN 'Security'       THEN 'Security'
        ELSE 'Other/Unclassified'
    END AS it_tower,

    -- Hardcoding IT Service maping
    CASE TRIM(COALESCE(NULLIF(i.category, ''), NULLIF(v.category, '')))
        WHEN 'Infrastructure' THEN 'Core Infra'
        WHEN 'SaaS'           THEN 'SaaS Apps'
        WHEN 'Software'       THEN 'On-Premise Software'
        WHEN 'Hardware'       THEN 'Client Computing'
        WHEN 'Consulting'     THEN 'Professional Services'
        WHEN 'Support'        THEN 'Helpdesk/Support'
        WHEN 'Telecom'        THEN 'Network'
        WHEN 'Security'       THEN 'Security Ops'
        ELSE 'Other Services'
    END AS it_service,

    -- Hardcoding cost_type (Run vs Grow)
    CASE TRIM(COALESCE(NULLIF(i.category, ''), NULLIF(v.category, '')))
        WHEN 'Hardware'       THEN 'Grow'
        WHEN 'Consulting'     THEN 'Grow'
        ELSE 'Run'
    END AS cost_type,

    CASE WHEN i.is_capex = 1 THEN 'CapEx' ELSE 'OpEx' END AS financial_category,
    cc.department_name,
    i.amount_gross
FROM invoices i
JOIN vendors v ON i.vendor_id = v.vendor_id
JOIN cost_centers cc ON i.cost_center_id = cc.cost_center_id
;


SELECT 
    it_tower, 
    cost_type, 
    financial_category, 
    SUM(amount_gross) AS total_spend_pln,
    COUNT(invoice_id) AS transaction_count
FROM v_final_spend_analysis
GROUP BY it_tower, cost_type, financial_category
ORDER BY total_spend_pln DESC
;

-- 1.6 Shadow IT Identification

SELECT 
    v.vendor_name,
    v.category AS vendor_category,
    COUNT(i.invoice_id) AS total_invoices,
    SUM(i.amount_gross) AS unauthorized_spend_pln
FROM invoices i
JOIN vendors v ON i.vendor_id = v.vendor_id
LEFT JOIN contracts c ON v.vendor_id = c.vendor_id
WHERE c.contract_id IS NULL -- Key Value: Lack of agreement
GROUP BY v.vendor_id, v.vendor_name, v.category
ORDER BY unauthorized_spend_pln DESC
;