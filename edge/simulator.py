import paho.mqtt.client as mqtt
import json
import time
import random
from datetime import datetime

# Configuration
MQTT_BROKER = "broker.hivemq.com"
MQTT_PORT = 1883
FLEET = ["truck_01", "truck_02", "truck_03"]

# Truck-specific states
truck_states = {
    tid: {"lat": 28.6139 + (i * 0.05), "lon": 77.2090 + (i * 0.05)}
    for i, tid in enumerate(FLEET)
}

ML_STATES = ["STATIC", "DRIVING", "VIBRATION", "SHOCK"]
ML_REASONS = ["Truck Parked", "Normal Motion", "Road Bumps", "Critical Impact"]

def generate_telemetry(device_id):
    state = truck_states[device_id]
    
    # Base values
    temp = 4.0 + random.uniform(-1, 5)  # Normal range: 3-9°C
    humidity = 45.0 + random.uniform(-5, 5)
    
    # truck_02 is a "trouble" truck (50% chance of breach)
    if device_id == "truck_02" and random.random() < 0.5:
        temp += 12.0
        
    # truck_03 has a "rough driver" (40% chance of shock)
    shock = (device_id == "truck_03" and random.random() < 0.4) or (random.random() < 0.05)
    
    # Update state (movement simulation)
    state["lat"] += random.uniform(-0.001, 0.001)
    state["lon"] += random.uniform(-0.001, 0.001)
    
    # Generate Accelerometer Data
    ax = round(random.uniform(-1, 1), 2)
    ay = round(random.uniform(-1, 1), 2)
    az = round(9.8 + random.uniform(-1, 1), 2)
    
    # Simulate high vibration for truck_03 occasionally
    if device_id == "truck_03" and random.random() < 0.2:
        az += random.uniform(3, 8)
    
    # If simulated shock was triggered earlier
    if shock:
        az += random.uniform(11, 25)

    # Edge Intelligence: TinyML Classifier Logic (Decision Tree)
    import math
    net_accel = math.sqrt(ax**2 + ay**2 + az**2)
    vertical_g = abs(az - 9.8)
    lateral_g = math.sqrt(ax**2 + ay**2)
    
    if net_accel < 10.3 and vertical_g < 0.3:
        ml_state = 0 # STATIC
    elif vertical_g > 10.0 or net_accel > 20.0:
        ml_state = 3 # SHOCK
    elif vertical_g > 2.0 or lateral_g > 1.5:
        ml_state = 2 # VIBRATION
    else:
        ml_state = 1 # DRIVING
    
    # Update status based on ML prediction
    actual_shock = (ml_state == 3)
    
    payload = {
        "device_id": device_id,
        "temp_c": round(temp, 2),
        "humidity": round(humidity, 2),
        "shock_event": actual_shock,
        "ml_shock_prediction": actual_shock,
        "ml_confidence": round(random.uniform(0.70, 0.99), 2),
        "ml_state": ml_state,
        "ml_label": ML_STATES[ml_state],
        "ml_reason": ML_REASONS[ml_state],
        "accel_x": ax,
        "accel_y": ay,
        "accel_z": az,
        "latitude": round(state["lat"], 6),
        "longitude": round(state["lon"], 6),
        "timestamp": int(time.time())
    }
    return payload

def main():
    print(f"==========================================")
    print(f"   Cold-Chain fleet Simulator v2.0")
    print(f"   Fleet Size: {len(FLEET)} Trucks")
    print(f"   Broker:     {MQTT_BROKER}:{MQTT_PORT}")
    print(f"==========================================\n")

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
    except Exception as e:
        print(f"[Error] Connecting to broker: {e}")
        return

    client.loop_start()

    try:
        while True:
            for device_id in FLEET:
                data = generate_telemetry(device_id)
                topic = f"coldchain/telemetry/{device_id}"
                payload = json.dumps(data)
                
                client.publish(topic, payload)
                print(f"[{datetime.now().strftime('%H:%M:%S')}] {device_id} -> Published telemetry")
            
            print("-" * 50)
            time.sleep(3)  # Send batch every 3 seconds to keep logs readable
            
    except KeyboardInterrupt:
        print("\nStopping Fleet Simulator...")
    finally:
        client.loop_stop()
        client.disconnect()

if __name__ == "__main__":
    main()
