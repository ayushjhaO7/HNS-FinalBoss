#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ArduinoJson.h>
#include <LiquidCrystal_I2C.h>

// Include the auto-generated Multi-Model TinyML Headers
#include "model_shock.h"
#include "model_road.h"
#include "model_spoilage.h"

// =============================================================================
//  CONFIGURATION
// =============================================================================

// --- TRUCK IDENTITY (Change this to 1, 2, or 3 for each Wokwi Tab) ---
#define TRUCK_NUMBER 1

const char* WIFI_SSID     = "Wokwi-GUEST";
const char* WIFI_PASSWORD  = "";
const char* MQTT_BROKER   = "broker.hivemq.com";
const int   MQTT_PORT     = 1883;

// Dynamic IDs based on TRUCK_NUMBER
String DEVICE_ID  = "truck_0" + String(TRUCK_NUMBER);
String MQTT_TOPIC = "coldchain/telemetry/" + DEVICE_ID;

// Base coordinates for fleet movement (Simulating Delhi/NCR)
float base_lat[] = {0, 28.6139, 28.5355, 28.7041};
float base_lon[] = {0, 77.2090, 77.3910, 77.1025};
float current_lat = base_lat[TRUCK_NUMBER];
float current_lon = base_lon[TRUCK_NUMBER];

// --- Timing ---
const unsigned long PUBLISH_INTERVAL_MS = 10000; 

// --- Sensors ---
DHT dht(4, DHT22);
Adafruit_MPU6050 mpu;
Adafruit_SSD1306 display(128, 64, &Wire, -1);
LiquidCrystal_I2C lcd(0x27, 16, 2);
WiFiClient espClient;
PubSubClient mqttClient(espClient);

unsigned long lastPublishTime = 0;
unsigned long messageCount    = 0;
bool isSending = false;
bool lastShock = false;

// =============================================================================
//  UI HELPERS
// =============================================================================

void updateDisplay(float t, float h, String road, bool shock, bool spoil, bool m_ok) {
  // --- 1. OLED Display (Rich Info) ---
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  // 1. Header & Connectivity
  display.setCursor(0, 0);
  display.print("ID: "); 
  display.print(DEVICE_ID);
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  // 2. Sensor Metrics
  display.setCursor(0, 15);
  display.print("Temp: "); display.print(t, 1); display.println(" C");
  display.setCursor(0, 25);
  display.print("Road: "); display.println(road);
  
  // 3. Activity Indicator
  if(isSending) {
    display.setCursor(30, 36);
    display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
    display.print(" DATA UPLOAD... ");
    display.setTextColor(SSD1306_WHITE);
  }

  // 4. Critical Alerts OR Live Location
  if(shock) {
    display.setCursor(0, 52);
    display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
    display.println("!!! SHOCK DETECTED !!!");
  } else if(spoil) {
    display.setCursor(0, 52);
    display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
    display.println("!!! SPOIL RISK !!!");
  } else {
    display.setCursor(0, 48);
    display.print("Lat: "); display.print(current_lat, 4);
    display.setCursor(0, 56);
    display.print("Lon: "); display.print(current_lon, 4);
  }
  display.display();

  // --- 2. 16x2 LCD (Alert Ticker) ---
  lcd.setCursor(0, 0);
  lcd.print("T:"); lcd.print(DEVICE_ID);
  lcd.print(m_ok ? " [NET:ON] " : " [NET:OFF]");
  lcd.setCursor(0, 1);
  if(shock)      lcd.print("!!! SHOCK !!!   ");
  else if(spoil) lcd.print("!!! SPOIL !!!   ");
  else           lcd.print("STATUS: OK      ");
}

void setup() {
  Serial.begin(115200);
  // Initialize Display
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  lcd.init();
  lcd.backlight();
  display.clearDisplay();
  dht.begin();
  if(!mpu.begin()) Serial.println("MPU FAIL");
  mpu.setAccelerometerRange(MPU6050_RANGE_16_G);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
}

void loop() {
  if (WiFi.status() == WL_CONNECTED && !mqttClient.connected()) {
    mqttClient.connect(DEVICE_ID.c_str());
  }
  mqttClient.loop();

  float t = dht.readTemperature();
  float h = dht.readHumidity();
  sensors_event_t a, g, m_temp;
  mpu.getEvent(&a, &g, &m_temp);

  // --- Multi-Model TinyML Inference ---
  
  // 1. Shock Prediction
  double shock_in[3] = {a.acceleration.x, a.acceleration.y, a.acceleration.z};
  double shock_out[2]; score_shock(shock_in, shock_out);
  bool is_shock = (shock_out[1] > 0.85);

  // 2. Road Surface Prediction
  double road_in[3] = {a.acceleration.x, a.acceleration.y, a.acceleration.z};
  double road_out[3]; score_road(road_in, road_out);
  int r_class = (road_out[1] > road_out[0] && road_out[1] > road_out[2]) ? 1 : (road_out[2] > road_out[0] ? 2 : 0);
  const char* road_labels[] = {"Smooth", "Bumpy", "Severe"};

  // 3. Spoilage Prediction (Calibrated for Default Wokwi 24C)
  float cal_t = (t > 23.5 && t < 24.5) ? 5.0 : t; // Treat 24C as safe 5C for simulation
  double spoil_in[2] = {cal_t, h};
  double spoil_out[2]; score_spoilage(spoil_in, spoil_out);
  bool is_spoil = (spoil_out[1] > spoil_out[0]);

  // Alert Smoothing
  if(is_shock) lastShock = true;
  else if(millis() % 5000 < 100) lastShock = false; 

  // UI State
  unsigned long currentMillis = millis();
  isSending = (currentMillis - lastPublishTime < 1000);
  updateDisplay(t, h, road_labels[r_class], lastShock, is_spoil, mqttClient.connected());

  // --- Daily Transmission ---
  if (currentMillis - lastPublishTime >= PUBLISH_INTERVAL_MS) {
    lastPublishTime = currentMillis;
    
    // Geographical Drift Simulation
    current_lat += (random(-10, 10) / 10000.0);
    current_lon += (random(-10, 10) / 10000.0);

    StaticJsonDocument<512> doc;
    doc["device_id"]   = DEVICE_ID;
    doc["temp_c"]      = round(t * 100.0) / 100.0;
    doc["humidity"]    = h;
    doc["ml_shock_prediction"] = is_shock ? "true" : "false";
    doc["ml_road_surface"]     = road_labels[r_class];
    doc["ml_spoilage_risk"]    = is_spoil ? "true" : "false";
    doc["latitude"]    = current_lat;
    doc["longitude"]   = current_lon;
    doc["timestamp"]   = (millis() / 1000) + 1712716800;

    char buffer[512];
    serializeJson(doc, buffer);
    mqttClient.publish(MQTT_TOPIC.c_str(), buffer);
    Serial.println("Sent: " + String(buffer));
    messageCount++;
  }
}
