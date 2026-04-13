use rumqttc::{AsyncClient, MqttOptions, QoS, Event, Packet};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs::OpenOptions;
use std::io::Write;
use std::time::Duration;
use chrono::Utc;
use std::env;

#[derive(Debug, Deserialize, Serialize)]
struct Telemetry {
    device_id: String,
    temp_c: f64,
    humidity: f64,
    is_shock: bool,
    road_surface: String,
    is_spoil: bool,
    latitude: f64,
    longitude: f64,
    timestamp: i64,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("=== RUST HIGH-PERFORMANCE INGESTOR STARTING ===");

    // Environment Configuration
    let broker = env::var("MQTT_BROKER").unwrap_or_else(|_| "broker.hivemq.com".to_string());
    let port = env::var("MQTT_PORT").unwrap_or_else(|_| "1883".to_string()).parse::<u16>()?;
    let topic = env::var("MQTT_TOPIC").unwrap_or_else(|_| "coldchain/telemetry/#".to_string());
    let data_dir = env::var("DATA_DIR").unwrap_or_else(|_| "/shared/data".to_string());

    let mut mqttoptions = MqttOptions::new("rust_ingestor_client", &broker, port);
    mqttoptions.set_keep_alive(Duration::from_secs(5));

    let (client, mut eventloop) = AsyncClient::new(mqttoptions, 10);
    client.subscribe(&topic, QoS::AtMostOnce).await?;

    println!("[Rust] Connected to {}:{} | Topic: {}", broker, port, topic);

    let location_log_path = format!("{}/fleet_location_log.csv", data_dir);
    let staging_log_path = format!("{}/staging_telemetry.csv", data_dir);

    loop {
        match eventloop.poll().await {
            Ok(notification) => {
                if let Event::Incoming(Packet::Publish(publish)) = notification {
                    let payload = String::from_utf8_lossy(&publish.payload);
                    
                    if let Ok(data) = serde_json::from_str::<Value>(&payload) {
                        let truck_id = data["device_id"].as_str().unwrap_or("unknown");
                        let lat = data["latitude"].as_f64().unwrap_or(0.0);
                        let lon = data["longitude"].as_f64().unwrap_or(0.0);
                        let ingested_at = Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Micros, true);
                        
                        // 1. UPDATE REAL-TIME LOCATION LOG (High Frequency)
                        let location_line = format!("{},{},{},{}\n", truck_id, lat, lon, ingested_at);
                        if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(&location_log_path) {
                            let _ = file.write_all(location_line.as_bytes());
                        }

                        // 2. UPDATE STAGING TELEMETRY LOG (For Spark Archival)
                        let temp = data["temp_c"].as_f64().unwrap_or(0.0);
                        let hum = data["humidity"].as_f64().unwrap_or(0.0);
                        let shock = data["is_shock"].as_bool().unwrap_or(false);
                        let surface = data["road_surface"].as_str().unwrap_or("Smooth");
                        let spoil = data["is_spoil"].as_bool().unwrap_or(false);
                        let ts = data["timestamp"].as_i64().unwrap_or(0);
                        
                        // Format matches ingestion.py: [device_id, temp, humid, shock, surface, spoil, lat, lon, ts, ingested_at]
                        let staging_line = format!("{},{},{},{},{},{},{},{},{},{}\n", 
                            truck_id, temp, hum, shock, surface, spoil, lat, lon, ts, ingested_at);
                        
                        if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(&staging_log_path) {
                            let _ = file.write_all(staging_line.as_bytes());
                        }

                        println!("[Rust] Received: {} at ({}, {})", truck_id, lat, lon);
                    }
                }
            }
            Err(e) => {
                println!("[Rust] Connection Error: {}. Retrying...", e);
                tokio::time::sleep(Duration::from_secs(5)).await;
            }
        }
    }
}
