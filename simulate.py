import os
import time
import random

data_dir = 'shared/data'
os.makedirs(data_dir, exist_ok=True)
staging = os.path.join(data_dir, 'staging_telemetry.csv')

trucks = ['TRK-901', 'TRK-902', 'TRK-903', 'TRK-904', 'TRK-905']
lats = [40.7128, 34.0522, 41.8781, 29.7604, 39.7392]
longs = [-74.0060, -118.2437, -87.6298, -95.3698, -104.9903]

with open(staging, 'w') as f:
    f.write('timestamp,device_id,temp_c,humidity,vibration_z,latitude,longitude,ml_shock_prediction,ml_road_surface,ml_spoilage_risk,ml_anomaly_score\n')
    for i in range(150):
        tidx = i % 5
        device = trucks[tidx]
        lat = lats[tidx] + random.uniform(-0.01, 0.01)
        lon = longs[tidx] + random.uniform(-0.01, 0.01)
        temp = random.uniform(-25.0, 5.0)
        spoil = "true" if temp > -15.0 else "false"
        
        row = f"{int(time.time()) - (150-i)*5},{device},{temp:.1f},{random.uniform(40,60):.1f},{random.uniform(0.1, 10.0):.2f},{lat:.4f},{lon:.4f},{random.choice(['false', 'true'])},{random.choice(['asphalt', 'gravel', 'pothole'])},{spoil},{random.uniform(0,1):.2f}\n"
        f.write(row)

print("SUCCESS: Generated 150 simulated fleet metrics.")
print("The PySpark Ingestion Engine will package this into SQLite dynamically.")
