-- 7. Governance & Automation

-- 7.1. Alerting Engine

CREATE OR REPLACE VIEW v_contract_expiry_alerts AS
SELECT 
    cc.budget_owner,
    cc.department_name,
    v.vendor_name,
    c.contract_name,
    c.end_date,
    c.notice_period_days,
    DATE_SUB(c.end_date, INTERVAL c.notice_period_days DAY) AS notice_deadline_date,
    DATEDIFF(DATE_SUB(c.end_date, INTERVAL c.notice_period_days DAY), CURDATE()) AS days_until_deadline,
    CASE 
        WHEN DATEDIFF(DATE_SUB(c.end_date, INTERVAL c.notice_period_days DAY), CURDATE()) = 0 THEN '🔴 CRITICAL: Deadline is TODAY!'
        WHEN DATEDIFF(DATE_SUB(c.end_date, INTERVAL c.notice_period_days DAY), CURDATE()) BETWEEN 1 AND 14 THEN '⚠️ URGENT: Deadline is in 2 weeks'
        ELSE 'ℹ️ WARNING: Deadling is in 1 month'
    END AS alert_severity
FROM contracts c
JOIN vendors v ON c.vendor_id = v.vendor_id
JOIN cost_centers cc ON c.cost_center_id = cc.cost_center_id
WHERE c.status = 'Active'
  -- Triggering alerts only in 30 days window before deadline
  AND DATEDIFF(DATE_SUB(c.end_date, INTERVAL c.notice_period_days DAY), CURDATE()) BETWEEN 0 AND 30
  ;

-- 7.2. Approval Workflow and Assigning Approvers

DELIMITER $$

CREATE TRIGGER tg_validate_invoice_cost_center
BEFORE INSERT ON invoices
FOR EACH ROW
BEGIN
    DECLARE v_cc_active TINYINT(1);
    DECLARE v_dept_name VARCHAR(60);

    -- Pobieramy status i nazwę działu dla przypisanego cost_center_id
    SELECT is_active, department_name 
    INTO v_cc_active, v_dept_name
    FROM cost_centers
    WHERE cost_center_id = NEW.cost_center_id;

    -- Jeśli dział nie istnieje lub jest nieaktywny, blokujemy zapis faktury
    IF v_cc_active IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR GOVERNANCE: Cost Center does not exists!';
    ELSEIF v_cc_active = 0 THEN
        SET @err_msg = CONCAT('ERROR GOVERNANCE: Dept ', v_dept_name, ' is inactive. Cannot assign the cost!');
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = @err_msg;
    END IF;
END$$

DELIMITER ;

SHOW FULL TABLES IN it_spend WHERE Table_type = 'VIEW';
SHOW TRIGGERS IN it_spend LIKE 'invoices';
SELECT * FROM v_contract_expiry_alerts;
