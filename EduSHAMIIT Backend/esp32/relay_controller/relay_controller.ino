/*
 * EduSHAMIIT ESP32 Relay Controller
 * Controls 4-channel relay board for classroom automation
 * WiFi + MQTT communication with fallback HTTP
 */

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <WebServer.h>
#include <Preferences.h>

// ── Config — edit per device ────────────────────────────────
const char* WIFI_SSID   = "School_WiFi";
const char* WIFI_PASS   = "schoolwifipass";
const char* MQTT_SERVER = "192.168.1.100";   // Python server LAN IP
const char* DEVICE_ID   = "room_10a_board1"; // unique per room
const char* DEVICE_ROOM = "class_10a";

// ── Relay GPIO pins (active LOW) ─────────────────────────────
const int  RELAY_PINS[]   = {23, 22, 21, 19};
const char* RELAY_NAMES[] = {"fan", "light1", "light2", "projector"};
const int  NUM_RELAYS     = 4;

WiFiClient   espClient;
PubSubClient mqtt(espClient);
WebServer    http(80);
Preferences  prefs;

String buildStatusJson() {
  StaticJsonDocument<256> doc;
  doc["device_id"] = DEVICE_ID;
  doc["room_id"]   = DEVICE_ROOM;
  for (int i = 0; i < NUM_RELAYS; i++) {
    doc[RELAY_NAMES[i]] = digitalRead(RELAY_PINS[i]) == LOW ? "on" : "off";
  }
  String json;
  serializeJson(doc, json);
  return json;
}

void handleCommand(String device, String action) {
  for (int i = 0; i < NUM_RELAYS; i++) {
    if (device == RELAY_NAMES[i] || device == "all" ||
        (device == "all_lights" && i >= 1 && i <= 2)) {
      bool state = (action == "on");
      if (action == "toggle") state = digitalRead(RELAY_PINS[i]) == HIGH;
      digitalWrite(RELAY_PINS[i], state ? LOW : HIGH);  // active LOW!
      prefs.putBool(RELAY_NAMES[i], state);              // persist
    }
  }
  publishStatus();
}

void publishStatus() {
  String json = buildStatusJson();
  String topic = String("school/") + DEVICE_ROOM + "/status";
  mqtt.publish(topic.c_str(), json.c_str(), true);  // retained
}

void onMqttMessage(char* topic, byte* payload, unsigned int len) {
  StaticJsonDocument<128> doc;
  deserializeJson(doc, payload, len);
  String action = doc["action"].as<String>();
  String device = doc["device"].as<String>();
  handleCommand(device, action);
}

void setupHttpServer() {
  http.on("/status", HTTP_GET, []() {
    http.send(200, "application/json", buildStatusJson());
  });
  http.on("/control", HTTP_POST, []() {
    StaticJsonDocument<128> doc;
    deserializeJson(doc, http.arg("plain"));
    handleCommand(doc["device"], doc["action"]);
    http.send(200, "application/json", "{\"ok\":true}");
  });
  http.begin();
}

void reconnectMqtt() {
  int attempts = 0;
  while (!mqtt.connected() && attempts < 5) {
    if (mqtt.connect(DEVICE_ID)) {
      String topic = String("school/") + DEVICE_ROOM + "/control";
      mqtt.subscribe(topic.c_str());
      publishStatus();
      Serial.println("MQTT connected!");
    } else {
      attempts++;
      delay(2000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("EduSHAMIIT Relay Controller starting...");

  // Initialize relay pins
  prefs.begin("relays", false);
  for (int i = 0; i < NUM_RELAYS; i++) {
    pinMode(RELAY_PINS[i], OUTPUT);
    bool saved = prefs.getBool(RELAY_NAMES[i], false);
    digitalWrite(RELAY_PINS[i], saved ? LOW : HIGH);
  }

  // Connect WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected! IP: " + WiFi.localIP().toString());

  // Setup MQTT
  mqtt.setServer(MQTT_SERVER, 1883);
  mqtt.setCallback(onMqttMessage);

  // Setup HTTP fallback
  setupHttpServer();

  Serial.println("EduSHAMIIT Relay Controller ready!");
}

void loop() {
  if (!mqtt.connected()) {
    reconnectMqtt();
  }
  mqtt.loop();
  http.handleClient();
}