# 📦 Consolidated Stock - Warehouse Efficiency Script

## 📚 Project Overview

This project addresses a **high inventory cost problem** caused by **honeycomb locations** — where the same products with identical expiry dates were unnecessarily spread across multiple warehouse locations.  
By consolidating these stocks into fewer locations, warehouse operations become more efficient and costs are reduced.

As part of the **Data Team**, I developed an **automated data processing script** in **R** to identify and suggest consolidation opportunities, which are then visualized through a **Tableau report**.  
This system helped reduce warehouse inventory costs by **5%**.

---

## 🚀 Script Summary

The script:

- Connects to a **PostgreSQL database** to pull current warehouse stock data.
- Processes the data to **identify "honeycomb" products** (same item and expiry across multiple locations).
- Suggests **optimal consolidations** of these stocks based on available pallet capacity.
- Outputs **consolidation recommendations** into a new table for reporting and operational action.

---

## 🛠 Technologies Used

- **Language:** R
- **Libraries:**  
  - `readxl`
  - `DBI`
  - `RPostgres`
  - `reticulate`
  - `tidyverse`
  - `stringr`
  - `lubridate`
- **Database:** PostgreSQL
- **Visualization:** Tableau (external, based on the script output)

---

## 📂 Script Breakdown

1. **Environment Setup:**  
   - Clears the R environment.
   - Installs and loads necessary libraries.
   
2. **Data Extraction:**  
   - Connects to the PostgreSQL database.
   - Pulls the `stock_all_fg_location` table, excluding locations marked as `On Hold`.

3. **Data Transformation:**  
   - Groups products by warehouse, item code, description, and expiry date.
   - Filters products appearing in multiple locations (potential honeycomb cases).
   
4. **Consolidation Algorithm:**  
   - Attempts to consolidate stocks into fewer locations without exceeding pallet capacity.
   - Prefers larger stock quantities first to maximize efficiency.
   - Suggests which locations should move into which target locations.

5. **Result Processing:**  
   - Generates a table (`stock_fg_honeycomb`) containing:
     - Product info
     - From Location
     - To Location
     - Quantities
     - Timestamp of last update

6. **Data Output:**  
   - Writes the results back into the PostgreSQL database for use in Tableau.

---

## 📈 Key Results

- **5% reduction** in inventory holding costs.
- **Automation** of previously manual consolidation planning.
- **Faster operations** with better location utilization in warehouses.

---

## ⚙️ How to Run the Script

1. Ensure you have R and the necessary packages installed.
2. Set your working environment (especially library paths if needed).
3. Adjust database credentials if running in a different environment.
4. Run the script end-to-end.
5. Validate the output table `stock_fg_honeycomb` in the database.

---

## ⚡ Notes

- This script assumes that **pallet capacities** (`ctn_pallet`) are accurately maintained.
- Data must have valid **item codes** and **expiry dates** for proper grouping.
- Designed for a **Linux** environment but should be adaptable to other systems with minor adjustments.

---

## 👤 Author

- **Project Contributor:** Wahyu Widiawati  
- **Role:** Data Analyst
