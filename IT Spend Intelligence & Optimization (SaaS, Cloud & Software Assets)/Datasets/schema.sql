-- ============================================================
--  IT Spend Optimization & Cost Intelligence
--  MySQL Schema — generated dataset
--  Compatible: MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS it_spend;
USE it_spend;

-- cost_centers
CREATE TABLE cost_centers (
    cost_center_id      INT            PRIMARY KEY,
    department_name     VARCHAR(60)    NOT NULL,
    annual_budget       DECIMAL(12,2)  NOT NULL,
    budget_owner        VARCHAR(100),
    cost_center_code    CHAR(6)        UNIQUE,
    is_active           TINYINT(1)     DEFAULT 1
);

-- vendors
CREATE TABLE vendors (
    vendor_id           INT            PRIMARY KEY,
    vendor_name         VARCHAR(100)   NOT NULL,
    category            VARCHAR(40),
    region              VARCHAR(10),
    status              VARCHAR(20),
    credit_score        TINYINT        COMMENT 'Internal 0-100 credit rating',
    relationship_since  DATE,
    payment_terms_days  TINYINT,
    account_manager     VARCHAR(100),
    preferred           TINYINT(1)     DEFAULT 0
);

-- contracts
CREATE TABLE contracts (
    contract_id         INT            PRIMARY KEY,
    vendor_id           INT            NOT NULL,
    cost_center_id      INT            NOT NULL,
    contract_name       VARCHAR(200),
    contract_type       VARCHAR(50),
    start_date          DATE,
    end_date            DATE,
    total_value         DECIMAL(12,2),
    annual_value        DECIMAL(12,2),
    auto_renewal        TINYINT(1)     DEFAULT 0,
    notice_period_days  SMALLINT,
    status              VARCHAR(20),
    signed_by           VARCHAR(100),
    FOREIGN KEY (vendor_id)       REFERENCES vendors(vendor_id),
    FOREIGN KEY (cost_center_id)  REFERENCES cost_centers(cost_center_id)
);

-- employees
CREATE TABLE employees (
    employee_id         INT            PRIMARY KEY,
    first_name          VARCHAR(50),
    last_name           VARCHAR(50),
    email               VARCHAR(120)   UNIQUE,
    cost_center_id      INT,
    location            VARCHAR(60),
    hire_date           DATE,
    is_active           TINYINT(1)     DEFAULT 1,
    job_title           VARCHAR(80),
    FOREIGN KEY (cost_center_id) REFERENCES cost_centers(cost_center_id)
);

-- software_licenses
CREATE TABLE software_licenses (
    license_id              INT            PRIMARY KEY,
    vendor_id               INT            NOT NULL,
    cost_center_id          INT            NOT NULL,
    product_name            VARCHAR(100),
    category                VARCHAR(40),
    license_type            ENUM('Per-Seat','Enterprise','Open Source','Trial'),
    seats_purchased         SMALLINT,
    seats_used              SMALLINT,
    unit_price_monthly      DECIMAL(10,2)  COMMENT 'Per-seat only',
    annual_cost             DECIMAL(12,2),
    purchase_date           DATE,
    renewal_date            DATE,
    is_active               TINYINT(1)     DEFAULT 1,
    contract_id             INT,
    FOREIGN KEY (vendor_id)       REFERENCES vendors(vendor_id),
    FOREIGN KEY (cost_center_id)  REFERENCES cost_centers(cost_center_id),
    FOREIGN KEY (contract_id)     REFERENCES contracts(contract_id)
);

-- hardware_assets
CREATE TABLE hardware_assets (
    asset_id                INT            PRIMARY KEY,
    asset_tag               VARCHAR(20)    UNIQUE,
    category                VARCHAR(40),
    make                    VARCHAR(50),
    model                   VARCHAR(100),
    serial_number           VARCHAR(30)    UNIQUE,
    cost_center_id          INT            NOT NULL,
    assigned_to_employee    INT,
    location                VARCHAR(60),
    purchase_date           DATE,
    purchase_price          DECIMAL(10,2),
    current_book_value      DECIMAL(10,2),
    end_of_life_date        DATE,
    condition_status        ENUM('Excellent','Good','Fair','End of Life'),
    is_active               TINYINT(1)     DEFAULT 1,
    warranty_expiry         DATE,
    FOREIGN KEY (cost_center_id)         REFERENCES cost_centers(cost_center_id),
    FOREIGN KEY (assigned_to_employee)   REFERENCES employees(employee_id)
);

-- invoices
CREATE TABLE invoices (
    invoice_id          INT            PRIMARY KEY,
    vendor_id           INT            NOT NULL,
    cost_center_id      INT            NOT NULL,
    contract_id         INT,
    invoice_number      VARCHAR(20)    UNIQUE,
    invoice_date        DATE,
    due_date            DATE,
    paid_date           DATE,
    amount_net          DECIMAL(12,2),
    tax_amount          DECIMAL(12,2),
    amount_gross        DECIMAL(12,2),
    currency            CHAR(3)        DEFAULT 'PLN',
    category            VARCHAR(50),
    is_capex            TINYINT(1)     DEFAULT 0,
    status              ENUM('Paid','Pending','Overdue','Disputed'),
    description         VARCHAR(200),
    FOREIGN KEY (vendor_id)       REFERENCES vendors(vendor_id),
    FOREIGN KEY (cost_center_id)  REFERENCES cost_centers(cost_center_id),
    FOREIGN KEY (contract_id)     REFERENCES contracts(contract_id)
);

-- license_usage_log
CREATE TABLE license_usage_log (
    log_id              INT            PRIMARY KEY,
    license_id          INT            NOT NULL,
    snapshot_date       DATE,
    seats_active        SMALLINT,
    seats_purchased     SMALLINT,
    utilization_pct     DECIMAL(6,2),
    FOREIGN KEY (license_id) REFERENCES software_licenses(license_id)
);
