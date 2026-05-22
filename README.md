# IT Spend Intelligence & Optimization
**Enterprise IT Asset & Cost Management Platform | MySQL · Power BI · DAX**

---

> Built to demonstrate senior-level ITAM expertise: full-cycle asset governance, license compliance, cloud cost accountability, and procurement risk management — implemented end-to-end in SQL and Power BI.

---

## What This Project Solves

IT organizations typically struggle with four expensive problems:

| Problem | This Project's Answer |
|---|---|
| No single source of truth for IT spend | Master spend view with TBM taxonomy, CapEx/OpEx classification, and department mapping |
| Software licenses paid for but unused | SAM module with seat-level utilization tracking and shelfware quantification |
| Hardware assets assigned to gone employees | HAM module with offboarding gap detection and book value recovery estimation |
| Contracts auto-renewing without review | Procurement module with notice period radar and termination deadline alerts |
| Cloud spend without accountability | FinOps module with commitment tracking, burn rate forecasting, and untagged cost audit |
| Shadow IT spend outside procurement | Governance trigger blocking inactive cost centers + contract-less vendor detection |

---

## Data Model

8-table normalized star schema simulating a real enterprise IT environment.

![ERD Diagram](Entity%20Relationship%20Diagram.png)

```
invoices          → fact table (1,000 records, multi-currency)
vendors           → dimension: 50 vendors across 6 categories
cost_centers      → dimension: 15 departments with annual budgets
contracts         → dimension: 37 active contracts with notice periods
employees         → dimension: active and offboarded staff
hardware_assets   → dimension: 500 assets across 10 categories
software_licenses → dimension: per-seat and enterprise licenses
license_usage_log → fact table: monthly utilization snapshots
```

**Views:** `v_final_spend_analysis` · `v_contract_expiry_alerts`
**Triggers:** `tg_validate_invoice_cost_center`

---

## SQL — Technical Breakdown

### Module 0 · Exploratory Data Analysis
Data profiling and quality validation before any transformation.

```sql
-- Data quality check: category consistency across invoices and vendors
SELECT
    i.category AS invoice_cat,
    v.category AS vendor_cat,
    COUNT(*) as record_count
FROM invoices i
JOIN vendors v ON i.vendor_id = v.vendor_id
GROUP BY i.category, v.category;
```

**Techniques:** `UNION ALL` for multi-table profiling · `CASE` for warranty status banding · `DATE_ADD` for dataset date normalization

---

### Module 1 · Data Foundation & TBM Taxonomy
Builds the master spend view with TBM (Technology Business Management) cost classification — the analytical backbone for all downstream reporting.

```sql
-- TBM Tower mapping: classifying raw invoice categories into IT towers
CASE TRIM(COALESCE(NULLIF(i.category, ''), NULLIF(v.category, '')))
    WHEN 'Infrastructure' THEN 'Infrastructure'
    WHEN 'SaaS'           THEN 'Applications'
    WHEN 'Hardware'       THEN 'End User'
    WHEN 'Consulting'     THEN 'IT Management'
    WHEN 'Security'       THEN 'Security'
    ELSE 'Other/Unclassified'
END AS it_tower
```

**Techniques:** `CREATE OR REPLACE VIEW` · `COALESCE` + `NULLIF` for null-safe category resolution · Multi-level `CASE` for Run vs Grow classification · Shadow IT detection via `LEFT JOIN` on contracts

---

### Module 2 · Hardware Asset Management (HAM)
Full hardware lifecycle governance — from warranty risk to offboarding gap detection.

```sql
-- Identifying assets still assigned to inactive (offboarded) employees
SELECT
    ha.asset_tag,
    ha.category,
    CONCAT(e.first_name, ' ', e.last_name) AS former_employee,
    cc.budget_owner
FROM hardware_assets ha
JOIN employees e       ON ha.assigned_to_employee = e.employee_id
JOIN cost_centers cc   ON ha.cost_center_id = cc.cost_center_id
WHERE e.is_active = 0
  AND ha.is_active = 1;
```

**Techniques:** Multi-table `JOIN` · `DATE_ADD` + `CURDATE()` for 90-day warranty window · `CASE` for warranty status classification · Zombie asset detection (EOL status + unassigned + residual book value)

---

### Module 3 · Software Asset Management (SAM)
License compliance and cost optimization — the highest-ROI module in any ITAM program.

```sql
-- SAM Renewal Radar: low-utilization licenses approaching renewal
WITH LatestSnapshot AS (
    SELECT
        license_id,
        snapshot_date,
        utilization_pct,
        ROW_NUMBER() OVER (PARTITION BY license_id ORDER BY snapshot_date DESC) AS rn
    FROM license_usage_log
)
SELECT
    sl.product_name,
    sl.renewal_date,
    ls.utilization_pct,
    sl.annual_cost,
    ROUND(sl.annual_cost * (1 - (ls.utilization_pct / 100)), 2) AS potential_annual_saving
FROM LatestSnapshot ls
JOIN software_licenses sl ON ls.license_id = sl.license_id
JOIN vendors v            ON sl.vendor_id = v.vendor_id
WHERE ls.rn = 1
  AND ls.utilization_pct < 50.00
  AND sl.is_active = 1
ORDER BY potential_annual_saving DESC;
```

**Techniques:** `CTE` + `ROW_NUMBER() OVER (PARTITION BY)` for latest snapshot isolation · Self-join on `software_licenses` for duplicate vendor detection · `IF` + conditional `SUM` for Per-Seat waste calculation

---

### Module 4 · FinOps & Cloud Cost Intelligence
Cloud commitment accountability and budget forecasting.

```sql
-- EOY Cloud Spend Forecast: burn rate extrapolation by department
WITH CloudMonthlySpend AS (
    SELECT
        cost_center_id,
        AVG(amount_gross)  AS avg_monthly_spend,
        SUM(amount_gross)  AS total_spent_ytd,
        COUNT(DISTINCT EXTRACT(YEAR_MONTH FROM invoice_date)) AS months_invoiced
    FROM invoices
    WHERE category = 'Cloud Services'
      AND EXTRACT(YEAR FROM invoice_date) = EXTRACT(YEAR FROM CURDATE())
    GROUP BY cost_center_id
)
SELECT
    cc.department_name,
    ROUND(cms.total_spent_ytd + (cms.avg_monthly_spend * (12 - cms.months_invoiced)), 2)
        AS estimated_end_of_year_cost,
    CASE
        WHEN (cms.total_spent_ytd + (cms.avg_monthly_spend * (12 - cms.months_invoiced)))
             > cc.annual_budget
        THEN 'ALARM: Overspend Forecast'
        ELSE 'In Budget'
    END AS budget_alert_status
FROM CloudMonthlySpend cms
JOIN cost_centers cc ON cms.cost_center_id = cc.cost_center_id;
```

**Techniques:** `CTE` for monthly aggregation · `EXTRACT(YEAR_MONTH)` for distinct month counting · Dynamic EOY forecasting formula · `COALESCE` for contracts with no invoices yet

---

### Module 5 · Procurement Analytics & Contract Management
Vendor risk management, cashflow optimization, and auto-renewal prevention.

```sql
-- Notice Period Radar: days remaining before termination deadline
SELECT
    c.contract_name,
    v.vendor_name,
    DATE_SUB(c.end_date, INTERVAL c.notice_period_days DAY) AS notice_deadline_date,
    DATEDIFF(
        DATE_SUB(c.end_date, INTERVAL c.notice_period_days DAY),
        CURDATE()
    ) AS days_left_to_act,
    c.auto_renewal,
    cc.budget_owner
FROM contracts c
JOIN vendors v      ON c.vendor_id = v.vendor_id
JOIN cost_centers cc ON c.cost_center_id = cc.cost_center_id
WHERE c.status = 'Active'
  AND c.end_date >= CURDATE()
ORDER BY days_left_to_act ASC;
```

**Techniques:** `DATE_SUB` + `DATEDIFF` for deadline arithmetic · `CTE` for total spend base (vendor concentration %) · Payment efficiency analysis via `paid_date` vs `due_date` delta

---

### Module 6 · Business Intelligence & Dashboarding
Executive-ready reporting: budget performance, vendor scorecards, and savings quantification.

```sql
-- Savings Tracker: unified view combining SAM and HAM optimization value
SELECT 'Software License Optimization' AS savings_source,
    ROUND(SUM(sl.annual_cost * (1 - (lu.utilization_pct / 100))), 2) AS total_annual_savings
FROM software_licenses sl
JOIN (...ROW_NUMBER for latest snapshot...) lu ON sl.license_id = lu.license_id
WHERE lu.utilization_pct < 50 AND sl.is_active = 1

UNION ALL

SELECT 'Hardware Asset Recovery (Offboarding)',
    ROUND(SUM(ha.current_book_value), 2)
FROM hardware_assets ha
JOIN employees e ON ha.assigned_to_employee = e.employee_id
WHERE e.is_active = 0 AND ha.is_active = 1;
```

**Techniques:** `UNION ALL` for cross-domain savings aggregation · Subquery with `ROW_NUMBER()` for latest utilization · CapEx refresh forecast with `BETWEEN CURDATE() AND DATE_ADD`

---

### Module 7 · Governance & Automation
Systematic controls that enforce ITAM policy without manual intervention.

**Contract Expiry Alerting View** — auto-generates severity-classified alerts within 30-day window:
```sql
CREATE OR REPLACE VIEW v_contract_expiry_alerts AS
SELECT
    CASE
        WHEN DATEDIFF(...) = 0            THEN 'CRITICAL: Deadline is TODAY'
        WHEN DATEDIFF(...) BETWEEN 1 AND 14 THEN 'URGENT: Deadline in 2 weeks'
        ELSE                                   'WARNING: Deadline in 1 month'
    END AS alert_severity
FROM contracts c ...
WHERE DATEDIFF(...) BETWEEN 0 AND 30;
```

**Invoice Governance Trigger** — blocks invoice creation against inactive cost centers at database level:
```sql
CREATE TRIGGER tg_validate_invoice_cost_center
BEFORE INSERT ON invoices
FOR EACH ROW
BEGIN
    -- Raises SQLSTATE '45000' if cost center inactive or non-existent
    -- Enforces data integrity without relying on application-layer validation
END$$
```

**Techniques:** `CREATE OR REPLACE VIEW` · `DELIMITER` + `CREATE TRIGGER` · `SIGNAL SQLSTATE` for custom error raising · `DECLARE` variables for multi-step validation logic

---

## Power BI Dashboards

### Executive Overview
![Executive Overview](screenshots/01_executive_overview.png)
KPI cards · CapEx vs OpEx donut · Spend trend by year · Top 20 vendors · Budget vs Actual by department

### HAM — Hardware Asset Management
![Hardware Assets](screenshots/02_ham_hardware_assets.png)
Warranty status table · Zombie asset detection · Assets by condition · Assets by category · Refresh cost KPI

### SAM — Software License Management
![Software Licenses](screenshots/03_sam_software_licenses.png)
Utilization by product · Shelfware table · SAM Renewal Radar · Licenses by category · Wasted cost KPI

### FinOps — Cloud Cost Intelligence
![FinOps](screenshots/04_finops_cloud_budget.png)
Monthly burn rate · Cloud spend by department · Budget vs Actual table · Untagged cloud costs audit

### Procurement & Contract Management
![Procurement](screenshots/05_procurement_contracts.png)
Contract Expiry Radar · Top vendors by spend (preferred vs non-preferred) · Shadow IT invoices · Spend by category

### Savings Tracker
![Savings Tracker](screenshots/06_savings_tracker.png)
Potential SAM savings · Hardware recovery value · Savings by license · Offboarding recovery table

---

## DAX Measures (Selected)

```dax
-- Latest utilization snapshot per license using EARLIER()
Potential Annual Savings SAM =
SUMX(
    FILTER(software_licenses, software_licenses[is_active] = 1),
    VAR latestUtil =
        CALCULATE(MAXX(
            FILTER(license_usage_log,
                license_usage_log[license_id] = EARLIER(software_licenses[license_id])),
            license_usage_log[utilization_pct]))
    RETURN IF(latestUtil < 50, software_licenses[annual_cost] * (1 - (latestUtil / 100)), 0)
)

-- Shadow IT: invoices with no associated contract
Shadow IT Spend =
CALCULATE(SUM(invoices_main[amount_gross]), ISBLANK(invoices_main[contract_id]))

-- Budget burn rate
Budget Utilization % =
DIVIDE([Total Spend YTD], [Total Annual Budget], 0)
```

---

## Key Findings (Sample Dataset)

| Area | Finding | Value |
|---|---|---|
| Total IT Spend | Gross invoiced across all departments | 38,03M PLN |
| Budget Overrun | Spend vs annual budget | +215,95% |
| SAM | Potential annual savings from underutilized licenses | ~2M PLN |
| SAM | Monthly wasted spend on unused seats | 69,32K PLN |
| HAM | Book value recoverable from offboarding gaps | 1,71M PLN |
| HAM | Assets currently out of warranty | 109 assets |
| HAM | Assets expiring within 90 days | 20 assets |
| Procurement | Active contracts monitored | 37 |

---

## How to Run

### MySQL
```bash
# 1. Create schema
CREATE DATABASE it_spend;
USE it_spend;

# 2. Run scripts in order
source sql/0__Exploratory_Data_Analysis.sql
source sql/1__Data_Foundation.sql
# ... through 7__Governance_Automation.sql
```

### Power BI
1. Download all CSV files from `/data`
2. Open `IT_Spend_Intelligence.pbix`
3. `Home → Transform Data → Edit Source` — update paths to your local `/data` folder
4. Click `Refresh`

---

## Author

*Senior ITAM portfolio project demonstrating end-to-end IT cost governance — from data modelling and SQL analytics to Power BI dashboards and database-level automation.*
