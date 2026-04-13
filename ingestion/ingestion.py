import os
import sys
import json
import csv
import time
import sqlite3
import threading
from datetime import datetime
from pathlib import Path
import pandas as pd
import pymongo  # Direct Cloud Bridge
from pyspark.sql import SparkSession
from pyspark.sql.types import (
    StructType, StructField, StringType, FloatType,
    BooleanType, LongType, DoubleType
)
from pyspark.sql.functions import col, when, lit, count, avg, max as spark_max

# =============================================================================
#  CONFIGURATION
# =============================================================================
DATA_DIR     = os.environ.get("DATA_DIR", "../shared/data")
RAW_CSV_PATH = os.path.join(DATA_DIR, "staging_telemetry.csv")
MASTER_CSV   = os.path.join(DATA_DIR, "wokwi_master_log.csv")
GOLD_DATA_LAKE = os.path.join(DATA_DIR, "fleet_data_lake.parquet")
SQLITE_DB    = os.path.join(DATA_DIR, "telemetry.db")

# Connection to YOUR Atlas Cloud
MONGO_URI = "mongodb+srv://totoayush07_db_user:6HhaCzzmpZjQoMgP@cluster0.qdsjnyf.mongodb.net/"

CSV_HEADERS = [
    "device_id", "temp_c", "humidity", 
    "ml_shock_prediction", "ml_road_surface", "ml_spoilage_risk", 
    "latitude", "longitude", "timestamp", "ingested_at"
]

TELEMETRY_SCHEMA = StructType([
    StructField("device_id",   StringType(),  False),
    StructField("temp_c",      DoubleType(),  True),
    StructField("humidity",    DoubleType(),  True),
    StructField("ml_shock_prediction", StringType(), True),
    StructField("ml_road_surface", StringType(), True),
    StructField("ml_spoilage_risk", StringType(), True),
    StructField("latitude",   DoubleType(),  True),
    StructField("longitude",  DoubleType(),  True),
    StructField("timestamp",  LongType(),    True),
    StructField("ingested_at", StringType(), True),
])

# =============================================================================
#  SPARK PROCESSOR (The Hybrid Bridge)
# =============================================================================
class SparkProcessor:
    def __init__(self):
        self.spark = None
        self.mongo_client = None

    def initialize_engines(self):
        print("[System] Initializing Spark Archival Engine...")
        
        # 1. Spark (For local scaling)
        try:
            self.spark = (
                SparkSession.builder
                .appName("ColdChainArchivalWorker")
                .master("local[*]")
                .getOrCreate()
            )
            self.spark.sparkContext.setLogLevel("ERROR")
            print("[Spark] Local Archival Engine: ONLINE.")
        except Exception as e:
            print(f"[Spark] Error: {e}")

        # 2. PyMongo (For guaranteed Cloud Sync)
        try:
            self.mongo_client = pymongo.MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
            self.mongo_client.admin.command('ping')
            print("[Cloud] Direct Atlas Bridge: ONLINE.")
        except Exception as e:
            print(f"[Cloud] Atlas Connectivity Alert: {e}")

    def run_cycle(self):
        if not self.spark or not self.mongo_client:
            self.initialize_engines()
        
        while True:
            # Check for data every 30 seconds
            time.sleep(30)
            
            if not os.path.exists(RAW_CSV_PATH) or os.path.getsize(RAW_CSV_PATH) < 100:
                continue

            print("[Spark-Worker] Processing new telemetry batch from Rust Bridge...")
            try:
                # 1. READ & DATA PREP
                # Note: Rust appends, Spark reads. 
                df = self.spark.read.option("header", "false").schema(TELEMETRY_SCHEMA).csv(RAW_CSV_PATH)
                pdf = df.withColumn("processed_at", lit(datetime.utcnow().isoformat())).toPandas()
                
                # Clear Staging after successful read
                if not pdf.empty:
                    with open(RAW_CSV_PATH, "w", newline="") as f:
                        pass # Purge the file after Spark consumes it

                # 2. LOCAL SYNC (FAIL-SAFE)
                try:
                    conn = sqlite3.connect(SQLITE_DB)
                    pdf.to_sql("telemetry", conn, if_exists="append", index=False)
                    conn.close()
                    pdf.to_csv(MASTER_CSV, mode='a', header=not os.path.exists(MASTER_CSV), index=False)
                    print("[Local] Sync: OK.")
                except Exception as e:
                    print(f"[Local] Storage Alert: {e}")

                # 3. CLOUD SYNC
                if self.mongo_client:
                    try:
                        records = pdf.to_dict('records')
                        if records:
                            db = self.mongo_client.coldchain
                            db.telemetry.insert_many(records)
                            print(f"[Cloud] ✅ Sync complete ({len(records)} docs pushed).")
                    except Exception as e:
                        print(f"[Cloud] Atlas Sync skipped: {e}")

                # 4. DATA LAKE
                try:
                    df.write.mode("append").partitionBy("device_id").parquet(GOLD_DATA_LAKE)
                    print("[Local] Data Lake: OK.")
                except Exception as e:
                    print(f"[Local] Lake Error: {e}")

                # 5. BI RECALC
                self.recalculate_bi_tables()

                print(f"[System] Batch Optimized: {len(pdf)} records finalized.")
                
            except Exception as e:
                print(f"[System] Cycle Error: {e}")

    def recalculate_bi_tables(self):
        try:
            conn = sqlite3.connect(SQLITE_DB)
            full_df = pd.read_sql("SELECT * FROM telemetry", conn)
            
            if full_df.empty:
                conn.close()
                return

            full_df['temp_c'] = pd.to_numeric(full_df['temp_c'])
            full_df['is_shock'] = full_df['ml_shock_prediction'].astype(str).str.lower().str.contains('true')
            full_df['is_spoil'] = full_df['ml_spoilage_risk'].astype(str).str.lower().str.contains('true')

            # Aggregate stats
            stats = full_df.groupby('device_id').agg(
                reading_count=('device_id', 'count'),
                avg_temp=('temp_c', 'mean'),
                temp_variance=('temp_c', 'var'),
                shock_events=('is_shock', 'sum'),
                avg_latitude=('latitude', 'mean'),
                avg_longitude=('longitude', 'mean'),
                last_seen=('ingested_at', 'max')
            ).reset_index().fillna(0)
            stats.to_sql("device_statistics", conn, if_exists="replace", index=False)

            # Spoilage Logic
            spoilage = full_df.groupby('device_id').agg(
                max_temp=('temp_c', 'max'),
                total_shocks=('is_shock', 'sum')
            ).reset_index()
            
            def classify_status(row):
                status = "SAFE"
                reason = "None"
                if row['max_temp'] > 8.0 or row['total_shocks'] > 0:
                    status = "SPOILED"
                    reason = "Critical Breach"
                loss = 50000.0 if status == "SPOILED" else 0.0
                return pd.Series([reason, status, loss])

            spoilage[['spoilage_reason', 'status', 'financial_loss']] = spoilage.apply(classify_status, axis=1)
            spoilage.to_sql("spoilage_results", conn, if_exists="replace", index=False)
            
            conn.close()
        except Exception as e:
            print(f"[BI] Error: {e}")

# =============================================================================
#  SYSTEM STARTER
# =============================================================================
if __name__ == "__main__":
    print("=====================================================")
    print("      SPARK ARCHIVAL WORKER (RUST-DRIVEN)            ")
    print("=====================================================")
    
    spark_worker = SparkProcessor()
    spark_worker.run_cycle()
