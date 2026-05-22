# 📊 Portfolio Projects
**Data Analytics & Business Intelligence**

This repository contains end-to-end analytics projects built on real-world business scenarios. Each project covers the full cycle — from data modelling and SQL analytics to dashboards and automation — using industry-standard tools.

Projects focus on:
- IT Asset & Cost Management (ITAM / FinOps)
- Business Intelligence & Dashboarding
- Data cleaning, modelling, and governance
- Procurement & contract analytics
- Cloud cost intelligence

---

## 🗂️ Projects Overview

| # | Project | Tools | Domain | Status |
|---|---|---|---|---|
| 1 | [IT Spend Intelligence & Optimization](#-it-spend-intelligence--optimization) | MySQL · Power BI · DAX | ITAM / FinOps | ✅ Completed |

*More projects coming soon — Python, Excel, Tableau*

---

## 🔹 IT Spend Intelligence & Optimization

**MySQL · Power BI · DAX**

![Executive Overview](https://raw.githubusercontent.com/Grandlad/Portfolio-Projects/main/IT%20Spend%20Intelligence%20%26%20Optimization%20(SaaS%2C%20Cloud%20%26%20Software%20Assets)/PowerBI/Screen_Shots/IT%20Spend%20Intelligence%20-%20Executive%20Overview.png)

An enterprise-grade IT Asset & Cost Management platform simulating a real IT department's financial operations. Built end-to-end: normalized MySQL schema → SQL analytics → Power BI dashboards → database-level governance.

| Module | What It Does |
|---|---|
| 🗃️ **Data Foundation** | Master spend view with TBM taxonomy, CapEx/OpEx classification, Shadow IT detection |
| 🖥️ **Hardware Asset Management** | Warranty radar, zombie asset detection, offboarding compliance |
| 💿 **Software Asset Management** | License utilization, shelfware detection, renewal radar |
| ☁️ **FinOps & Cloud Intelligence** | Commitment tracking, burn rate forecasting, untagged cost audit |
| 📋 **Procurement & Contracts** | Notice period radar, vendor concentration, cashflow efficiency |
| 📊 **BI & Dashboarding** | Budget vs Actual, vendor scorecards, savings tracker, CapEx dashboard |
| 🔒 **Governance & Automation** | Contract expiry alerting view, invoice validation trigger |

**Database:** 8 tables · 2 views · 1 trigger · MySQL 8.x

**Key findings (sample dataset):**

| Metric | Value |
|---|---|
| Total IT Spend analysed | 38,03M PLN |
| Potential SAM savings | ~2M PLN / year |
| Hardware recovery value | 1,71M PLN |
| Assets out of warranty | 109 |
| Monthly wasted license cost | 69,32K PLN |

### SQL Techniques Used
- Window Functions (`ROW_NUMBER() OVER PARTITION BY`)
- Common Table Expressions (CTEs)
- Views, Triggers, Stored Logic (`SIGNAL SQLSTATE`)
- Date arithmetic (`DATE_SUB`, `DATEDIFF`, `EXTRACT`)
- Multi-table JOINs, conditional aggregations, UNION ALL

### Power BI
- Star schema data model (8 tables, active/inactive relationships)
- 20+ DAX measures including `USERELATIONSHIP`, `EARLIER`, `SUMX`, `DATEVALUE`
- 6 report pages: Executive Overview · HAM · SAM · FinOps · Procurement · Savings Tracker

📁 [View Project Folder](IT%20Spend%20Intelligence%20%26%20Optimization%20(SaaS%2C%20Cloud%20%26%20Software%20Assets)/)

---

## 🛠️ Skills Demonstrated

- Data modelling & normalization (star schema)
- Exploratory Data Analysis (EDA)
- Window Functions (`ROW_NUMBER`, `PARTITION BY`)
- Common Table Expressions (CTEs)
- Views, Triggers, and Stored Logic
- FinOps & IT Financial Governance (TBM, CapEx/OpEx, Shadow IT)
- Power BI data modelling & DAX
- KPI reporting and executive dashboarding
- Contract & procurement analytics

---

## 👤 Author

**Grandlad** · [GitHub](https://github.com/Grandlad)
