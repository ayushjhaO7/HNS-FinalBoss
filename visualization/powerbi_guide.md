# Power BI Dashboard Setup Guide
## Cold-Chain Vaccine & Medicine Logistics Tracker

---

## Table of Contents
1. [Connecting Power BI to the Data](#1-connecting-power-bi-to-the-data)
2. [Understanding the Data Tables](#2-understanding-the-data-tables)
3. [DAX Formulas](#3-dax-formulas)
4. [Building the Dashboard](#4-building-the-dashboard)
5. [Map Visualization Setup](#5-map-visualization-with-conditional-colors)

---

## 1. Connecting Power BI to the Data

### Option A: Connect to SQLite via ODBC (Recommended)

1. **Install the SQLite ODBC Driver**
   - Download from: http://www.ch-werner.de/sqliteodbc/
   - Install the 64-bit version: `sqliteodbc_w64.exe`

2. **Set up an ODBC Data Source**
   - Open **ODBC Data Source Administrator (64-bit)** from Windows search
   - Click **Add** → Select **SQLite3 ODBC Driver** → Click **Finish**
   - Set **Data Source Name**: `ColdChainDB`
   - Set **Database Name**: Browse to your `shared/data/telemetry.db` file
   - Click **OK**

3. **Connect from Power BI**
   - Open Power BI Desktop
   - Click **Get Data** → **ODBC**
   - Select the `ColdChainDB` data source
   - You should see three tables: `telemetry`, `spoilage_results`, `device_statistics`
   - Select all three and click **Load**

### Option B: Connect via CSV Export
If you prefer simplicity, export the SQLite tables to CSV:
```bash
sqlite3 shared/data/telemetry.db
.headers on
.mode csv
.output telemetry.csv
SELECT * FROM telemetry;
.output spoilage_results.csv
SELECT * FROM spoilage_results;
.output device_statistics.csv
SELECT * FROM device_statistics;
.quit
```
Then in Power BI: **Get Data** → **Text/CSV** → Load each file.

---

## 2. Understanding the Data Tables

### `telemetry` — Raw Sensor Readings
| Column | Type | Description |
|--------|------|-------------|
| device_id | Text | Truck identifier (e.g., "truck_01") |
| temp_c | Decimal | Temperature in Celsius |
| humidity | Decimal | Relative humidity % |
| shock_event | Boolean | Physical shock detected |
| accel_x/y/z | Decimal | Acceleration vectors (m/s²) |
| latitude | Decimal | GPS latitude |
| longitude | Decimal | GPS longitude |
| timestamp | Integer | Unix epoch timestamp |
| ingested_at | DateTime | When the data was ingested |
| processed_at | DateTime | When PySpark processed it |

### `spoilage_results` — Analysis Output
| Column | Type | Description |
|--------|------|-------------|
| device_id | Text | Truck identifier |
| spoilage_reason | Text | "None", "Temperature Breach", "Shock Event", or both |
| spoilage_count | Integer | Number of spoilage triggers |
| status | Text | "SAFE" or "SPOILED" |
| financial_loss | Decimal | Loss in USD ($50,000 per spoiled shipment) |

### `device_statistics` — Aggregated Metrics
| Column | Type | Description |
|--------|------|-------------|
| device_id | Text | Truck identifier |
| reading_count | Integer | Total readings |
| avg_temp | Decimal | Mean temperature |
| temp_variance | Decimal | Temperature variance |
| temp_std_dev | Decimal | Temperature standard deviation |
| shock_events | Integer | Count of shock events |
| avg_latitude / avg_longitude | Decimal | Average GPS position |

---

## 3. DAX Formulas

### 3.1 Total Financial Risk (KPI Card)

Create this measure in the `spoilage_results` table:
```dax
Total Financial Risk = 
SUMX(
    FILTER(
        spoilage_results,
        spoilage_results[status] = "SPOILED"
    ),
    spoilage_results[financial_loss]
)
```

**How to use:**
1. Add a **Card** visual to your canvas
2. Drag `Total Financial Risk` into the **Fields** well
3. Format → Callout value → Display units: **None**
4. Format → Callout value → Prefix: **$**

### 3.2 Spoiled Shipment Count (KPI Card)

```dax
Spoiled Count = 
COUNTROWS(
    FILTER(
        spoilage_results,
        spoilage_results[status] = "SPOILED"
    )
)
```

### 3.3 Safe Shipment Count (KPI Card)

```dax
Safe Count = 
COUNTROWS(
    FILTER(
        spoilage_results,
        spoilage_results[status] = "SAFE"
    )
)
```

### 3.4 Spoilage Rate Percentage (KPI Card)

```dax
Spoilage Rate % = 
DIVIDE(
    [Spoiled Count],
    COUNTROWS(spoilage_results),
    0
) * 100
```

### 3.5 Average Temperature Variance Per Truck

Create this measure in the `device_statistics` table:
```dax
Avg Temp Variance = 
AVERAGEX(
    VALUES(device_statistics[device_id]),
    CALCULATE(
        AVERAGE(device_statistics[temp_variance])
    )
)
```

### 3.6 Individual Truck Temperature Variance

For a table/matrix visual showing per-truck variance:
```dax
Truck Temp Variance = 
VAR CurrentDevice = SELECTEDVALUE(device_statistics[device_id])
RETURN
    CALCULATE(
        AVERAGE(device_statistics[temp_variance]),
        device_statistics[device_id] = CurrentDevice
    )
```

### 3.7 Risk Level Classification (Calculated Column)

Add this as a calculated column on `spoilage_results`:
```dax
Risk Level = 
SWITCH(
    TRUE(),
    spoilage_results[status] = "SPOILED" 
        && CONTAINSSTRING(spoilage_results[spoilage_reason], "Temperature Breach") 
        && CONTAINSSTRING(spoilage_results[spoilage_reason], "Shock Event"),
        "CRITICAL",
    spoilage_results[status] = "SPOILED",
        "HIGH",
    RELATED(device_statistics[avg_temp]) > 6.0,
        "MEDIUM",
    "LOW"
)
```

### 3.8 Dynamic Color Measure (for Conditional Formatting)

```dax
Status Color = 
SWITCH(
    SELECTEDVALUE(spoilage_results[status]),
    "SPOILED", "#E74C3C",
    "SAFE", "#27AE60",
    "#95A5A6"
)
```

---

## 4. Building the Dashboard

### Recommended Page Layout

```
╔══════════════════════════════════════════════════════════════╗
║  🏷️ COLD-CHAIN LOGISTICS TRACKER DASHBOARD                  ║
╠════════════╦═══════════╦═══════════╦═════════════════════════╣
║  💰 Total  ║  ❌ Spoiled ║  ✅ Safe   ║  📊 Spoilage Rate     ║
║  Financial ║  Count    ║  Count    ║     (Gauge)            ║
║  Risk      ║           ║           ║                        ║
║  $150,000  ║     3     ║     2     ║      60%               ║
╠════════════╩═══════════╩═══════════╩═════════════════════════╣
║                                                              ║
║   🗺️ MAP VISUALIZATION                                       ║
║   (Trucks colored Green/Yellow/Red based on status)          ║
║                                                              ║
╠══════════════════════════╦═══════════════════════════════════╣
║  📈 Temperature Timeline ║  📋 Device Summary Table          ║
║  (Line chart per truck)  ║  Truck | Status | Temp | Loss    ║
║                          ║  truck_01 | SPOILED | 9.2 | $50K ║
║                          ║  truck_02 | SAFE | 4.1 | $0      ║
╚══════════════════════════╩═══════════════════════════════════╝
```

### Step-by-Step Build

#### Row 1: KPI Cards
1. Add 4 **Card** visuals across the top row
2. Assign: `Total Financial Risk`, `Spoiled Count`, `Safe Count`, and a **Gauge** for `Spoilage Rate %`
3. Apply conditional formatting using `Status Color` measure

#### Row 2: Map Visualization (see Section 5 below)

#### Row 3: Charts
1. **Temperature Timeline**: 
   - Visual type: **Line Chart**
   - X-axis: `telemetry[timestamp]`
   - Y-axis: `telemetry[temp_c]`
   - Legend: `telemetry[device_id]`
   - Add a **Constant Line** at Y = 8.0 (threshold) in red

2. **Device Summary Table**:
   - Visual type: **Table**
   - Columns: `device_id`, `status`, `spoilage_reason`, `avg_temp`, `financial_loss`
   - Apply conditional formatting on the `status` column

---

## 5. Map Visualization with Conditional Colors

### Step-by-Step: Truck Location Map

#### Prerequisites
- The `device_statistics` table must have `avg_latitude` and `avg_longitude` columns
- Create a relationship between `device_statistics[device_id]` and `spoilage_results[device_id]`

#### Step 1: Create the Map Color Measure

```dax
Map Color = 
VAR TruckStatus = SELECTEDVALUE(spoilage_results[status])
VAR AvgTemp = AVERAGE(device_statistics[avg_temp])
RETURN
SWITCH(
    TRUE(),
    TruckStatus = "SPOILED", "#E74C3C",
    AvgTemp > 6.0, "#F39C12",
    "#27AE60"
)
```

Color mapping:
| Condition | Color | Hex |
|-----------|-------|-----|
| Spoiled | 🔴 Red | #E74C3C |
| Warning (6°C+) | 🟡 Yellow/Orange | #F39C12 |
| Safe | 🟢 Green | #27AE60 |

#### Step 2: Add the Map Visual
1. Click on the **Map** visual (bubble map) in the Visualizations pane
2. Configure the field wells:
   - **Location**: `device_statistics[avg_latitude]` and `device_statistics[avg_longitude]`
   - **Legend**: `spoilage_results[status]`
   - **Size**: `device_statistics[reading_count]`
   - **Tooltips**: `device_id`, `avg_temp`, `financial_loss`

#### Step 3: Apply Conditional Coloring
1. Select the Map visual
2. Go to **Format visual** → **Bubbles** → **Colors**
3. Click the **fx** button (conditional formatting)
4. Set:
   - **Format style**: Rules
   - **What field should we base this on?**: `Map Color`
   - **Rule 1**: If value contains "#E74C3C" → Color: Red
   - **Rule 2**: If value contains "#F39C12" → Color: Orange
   - **Rule 3**: If value contains "#27AE60" → Color: Green

**Alternative (simpler):**
1. Instead of the `fx` button, just use the Legend:
   - With `spoilage_results[status]` in the Legend field, Power BI auto-assigns colors
   - Click on each legend item to manually set:
     - "SPOILED" → Red (#E74C3C)
     - "SAFE" → Green (#27AE60)

#### Step 4: Add Drill-Through
1. Create a new page called "Truck Detail"
2. Add a **drill-through filter** on `device_id`
3. On the detail page, show:
   - Full temperature history line chart
   - Shock event timeline
   - Accelerometer readings

---

## Tips & Best Practices

1. **Auto-Refresh**: Set up Power BI scheduled refresh if connecting to a live database
2. **Bookmarks**: Create bookmarks for "All Trucks", "Spoiled Only", "Safe Only" views
3. **Color Theme**: Import a custom theme JSON to maintain consistent dashboard aesthetics
4. **Mobile Layout**: Design a separate mobile layout for field monitoring
5. **Alerts**: Set up data-driven alerts on the `Spoilage Rate %` KPI card to notify when it exceeds a threshold
