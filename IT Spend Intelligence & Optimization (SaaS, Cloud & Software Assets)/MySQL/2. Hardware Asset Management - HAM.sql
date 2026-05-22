-- Hardware Asset Management

-- 2.1 Warranty & Refresh Plan

SELECT 
    ha.asset_id,
    ha.asset_tag,
    ha.category,
    ha.make,
    ha.model,
    ha.warranty_expiry,
    ha.end_of_life_date,
    cc.department_name,
    cc.budget_owner
FROM hardware_assets ha
JOIN cost_centers cc ON ha.cost_center_id = cc.cost_center_id
WHERE ha.is_active = 1
  AND (ha.warranty_expiry <= DATE_ADD(CURDATE(), INTERVAL 90 DAY) OR ha.warranty_expiry < CURDATE())
ORDER BY ha.warranty_expiry ASC
;

-- 2.2. Finding out "Zombies"

SELECT 
    asset_id,
    asset_tag,
    category,
    make,
    model,
    condition_status,
    current_book_value,
    purchase_price
FROM hardware_assets
WHERE is_active = 1
  AND (
      condition_status = 'End of Life' 
      OR (assigned_to_employee IS NULL AND current_book_value > (purchase_price * 0.5))
  )
ORDER BY current_book_value DESC
;

-- 2.3. Unactive employees

SELECT 
    ha.asset_id,
    ha.asset_tag,
    ha.category AS asset_category,
    ha.make,
    ha.model,
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS former_employee,
    e.email AS former_employee_email,
    cc.department_name AS original_department,
    cc.budget_owner
FROM hardware_assets ha
JOIN employees e ON ha.assigned_to_employee = e.employee_id
JOIN cost_centers cc ON ha.cost_center_id = cc.cost_center_id
WHERE e.is_active = 0 
  AND ha.is_active = 1
;

