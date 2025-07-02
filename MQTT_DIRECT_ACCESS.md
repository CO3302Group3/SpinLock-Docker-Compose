# Direct MQTT Access Configuration

## Overview
The MQTT broker (Mosquitto) is now accessible directly on port 1883 for external publishing and internal subscribing.

## Configuration
- **MQTT Port:** 1883 (externally accessible)
- **WebSocket Port:** 9001 (for web clients - optional)
- **Anonymous Access:** Enabled for development

## Publishing from External Devices

### Using mosquitto_pub (command line)
```bash
# Publish a simple message
mosquitto_pub -h localhost -p 1883 -t "sensors/temperature" -m "23.5"

# Publish JSON data
mosquitto_pub -h localhost -p 1883 -t "sensors/data" -m '{"temperature":23.5,"humidity":65.2,"device_id":"sensor_001"}'

# Publish with QoS and retain
mosquitto_pub -h localhost -p 1883 -t "sensors/status" -m "online" -q 1 -r
```

### Using Python (paho-mqtt)
```python
import paho.mqtt.client as mqtt
import json
import time

# Create MQTT client
client = mqtt.Client()

# Connect to broker
client.connect("localhost", 1883, 60)

# Publish sensor data
sensor_data = {
    "device_id": "sensor_001",
    "temperature": 23.5,
    "humidity": 65.2,
    "timestamp": time.time()
}

client.publish("sensors/temperature", json.dumps(sensor_data))
client.disconnect()
```

### Using Arduino/ESP32
```cpp
#include <WiFi.h>
#include <PubSubClient.h>

const char* mqtt_server = "your-server-ip";
const int mqtt_port = 1883;

WiFiClient espClient;
PubSubClient client(espClient);

void setup() {
    client.setServer(mqtt_server, mqtt_port);
    // Connect to WiFi first...
    
    if (client.connect("ESP32Client")) {
        // Publish sensor data
        client.publish("sensors/temperature", "25.3");
    }
}

void publishSensorData(float temp, float humidity) {
    String payload = "{\"temperature\":" + String(temp) + 
                    ",\"humidity\":" + String(humidity) + "}";
    client.publish("sensors/data", payload.c_str());
}
```

### Using ESP-IDF (Espressif IoT Development Framework)
```c
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "esp_wifi.h"
#include "esp_system.h"
#include "nvs_flash.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "freertos/queue.h"
#include "lwip/sockets.h"
#include "lwip/dns.h"
#include "lwip/netdb.h"
#include "esp_log.h"
#include "mqtt_client.h"
#include "cJSON.h"

static const char *TAG = "MQTT_PUBLISHER";

// MQTT Configuration
#define MQTT_BROKER_HOST "your-server-ip"
#define MQTT_BROKER_PORT 1883
#define MQTT_CLIENT_ID "esp32_device_001"

static esp_mqtt_client_handle_t client;

// MQTT Event Handler
static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    esp_mqtt_event_handle_t event = event_data;
    esp_mqtt_client_handle_t client = event->client;
    
    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED:
        ESP_LOGI(TAG, "MQTT_EVENT_CONNECTED");
        break;
    case MQTT_EVENT_DISCONNECTED:
        ESP_LOGI(TAG, "MQTT_EVENT_DISCONNECTED");
        break;
    case MQTT_EVENT_PUBLISHED:
        ESP_LOGI(TAG, "MQTT_EVENT_PUBLISHED, msg_id=%d", event->msg_id);
        break;
    case MQTT_EVENT_ERROR:
        ESP_LOGI(TAG, "MQTT_EVENT_ERROR");
        break;
    default:
        ESP_LOGI(TAG, "Other event id:%d", event->event_id);
        break;
    }
}

// Initialize MQTT Client
void mqtt_app_start(void)
{
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker = {
            .address.hostname = MQTT_BROKER_HOST,
            .address.port = MQTT_BROKER_PORT,
        },
        .credentials = {
            .client_id = MQTT_CLIENT_ID,
        },
    };

    client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(client);
}

// Publish sensor data as JSON
void publish_sensor_data(float temperature, float humidity, const char* device_id)
{
    cJSON *json = cJSON_CreateObject();
    cJSON *temp = cJSON_CreateNumber(temperature);
    cJSON *hum = cJSON_CreateNumber(humidity);
    cJSON *device = cJSON_CreateString(device_id);
    cJSON *timestamp = cJSON_CreateNumber(esp_timer_get_time() / 1000000); // Unix timestamp
    
    cJSON_AddItemToObject(json, "temperature", temp);
    cJSON_AddItemToObject(json, "humidity", hum);
    cJSON_AddItemToObject(json, "device_id", device);
    cJSON_AddItemToObject(json, "timestamp", timestamp);
    
    char *json_string = cJSON_Print(json);
    
    int msg_id = esp_mqtt_client_publish(client, "sensors/data", json_string, 0, 1, 0);
    ESP_LOGI(TAG, "Published sensor data, msg_id=%d", msg_id);
    
    free(json_string);
    cJSON_Delete(json);
}

// Publish simple string message
void publish_string_message(const char* topic, const char* message)
{
    int msg_id = esp_mqtt_client_publish(client, topic, message, 0, 1, 0);
    ESP_LOGI(TAG, "Published message to %s, msg_id=%d", topic, msg_id);
}

// Publish device status
void publish_device_status(const char* device_id, const char* status)
{
    char topic[64];
    snprintf(topic, sizeof(topic), "devices/%s/status", device_id);
    
    cJSON *json = cJSON_CreateObject();
    cJSON *status_obj = cJSON_CreateString(status);
    cJSON *timestamp = cJSON_CreateNumber(esp_timer_get_time() / 1000000);
    
    cJSON_AddItemToObject(json, "status", status_obj);
    cJSON_AddItemToObject(json, "timestamp", timestamp);
    
    char *json_string = cJSON_Print(json);
    
    int msg_id = esp_mqtt_client_publish(client, topic, json_string, 0, 1, 1); // Retain message
    ESP_LOGI(TAG, "Published device status to %s, msg_id=%d", topic, msg_id);
    
    free(json_string);
    cJSON_Delete(json);
}

// Example task for periodic sensor publishing
void sensor_task(void *pvParameters)
{
    float temperature = 20.0;
    float humidity = 50.0;
    
    while (1) {
        // Simulate sensor readings
        temperature += (float)(esp_random() % 100 - 50) / 100.0; // ±0.5°C variation
        humidity += (float)(esp_random() % 100 - 50) / 200.0;    // ±0.25% variation
        
        // Keep values in realistic ranges
        if (temperature < 15.0) temperature = 15.0;
        if (temperature > 35.0) temperature = 35.0;
        if (humidity < 30.0) humidity = 30.0;
        if (humidity > 80.0) humidity = 80.0;
        
        // Publish sensor data
        publish_sensor_data(temperature, humidity, MQTT_CLIENT_ID);
        
        // Publish device heartbeat every 10 cycles
        static int cycle_count = 0;
        if (++cycle_count >= 10) {
            publish_device_status(MQTT_CLIENT_ID, "online");
            cycle_count = 0;
        }
        
        vTaskDelay(pdMS_TO_TICKS(30000)); // Publish every 30 seconds
    }
}

// Main application
void app_main(void)
{
    ESP_LOGI(TAG, "Starting MQTT Publisher");
    
    // Initialize NVS
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    
    // Initialize WiFi (add your WiFi connection code here)
    // wifi_init_sta();
    
    // Start MQTT client
    mqtt_app_start();
    
    // Create sensor task
    xTaskCreate(sensor_task, "sensor_task", 4096, NULL, 5, NULL);
}
```

### Simple ESP-IDF MQTT Publisher (Minimal Example)
```c
#include "esp_log.h"
#include "mqtt_client.h"
#include "nvs_flash.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"

static const char *TAG = "SIMPLE_MQTT";
static esp_mqtt_client_handle_t client;

static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    esp_mqtt_event_handle_t event = event_data;
    
    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED:
        ESP_LOGI(TAG, "MQTT Connected");
        // Publish a test message on connection
        esp_mqtt_client_publish(client, "test/esp32", "Hello from ESP32!", 0, 1, 0);
        break;
    case MQTT_EVENT_PUBLISHED:
        ESP_LOGI(TAG, "Message published successfully");
        break;
    case MQTT_EVENT_ERROR:
        ESP_LOGE(TAG, "MQTT Error occurred");
        break;
    default:
        break;
    }
}

void simple_mqtt_start(void)
{
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.hostname = "192.168.1.100", // Replace with your server IP
        .broker.address.port = 1883,
        .credentials.client_id = "esp32_simple",
    };

    client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(client);
}

void publish_temperature(float temp)
{
    char temp_str[16];
    snprintf(temp_str, sizeof(temp_str), "%.2f", temp);
    esp_mqtt_client_publish(client, "sensors/temperature", temp_str, 0, 1, 0);
}

void app_main(void)
{
    // Initialize NVS
    nvs_flash_init();
    
    // Initialize WiFi (implement wifi_init_sta() with your credentials)
    // wifi_init_sta();
    
    // Start MQTT
    simple_mqtt_start();
    
    // Example: Publish temperature every 10 seconds
    while(1) {
        publish_temperature(25.5);
        vTaskDelay(pdMS_TO_TICKS(10000));
    }
}
```

## Subscribing Internally

### Using mosquitto_sub (command line)
```bash
# Subscribe to all sensor topics
mosquitto_sub -h mqtt-broker -p 1883 -t "sensors/#" -v

# Subscribe to specific topic
mosquitto_sub -h mqtt-broker -p 1883 -t "sensors/temperature" -v

# Subscribe from external (for testing)
mosquitto_sub -h localhost -p 1883 -t "sensors/#" -v
```

### Using Python Subscriber
```python
import paho.mqtt.client as mqtt

def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")
    client.subscribe("sensors/#")

def on_message(client, userdata, msg):
    print(f"Topic: {msg.topic}, Message: {msg.payload.decode()}")

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

# For internal services, use the service name
client.connect("mqtt-broker", 1883, 60)

# For external testing, use localhost
# client.connect("localhost", 1883, 60)

client.loop_forever()
```

## Docker Service Access

### From other containers in the network
- **Host:** `mqtt-broker`
- **Port:** `1883`

### From external devices/applications
- **Host:** `localhost` or your server's IP
- **Port:** `1883`

## Starting the Services

```bash
# Start all services
docker-compose up -d

# Check MQTT broker logs
docker-compose logs mqtt-broker

# Test connectivity
mosquitto_pub -h localhost -p 1883 -t "test" -m "Hello MQTT!"
```

## Topic Organization
Recommended topic structure:
- `sensors/{device_type}` - Sensor readings
- `devices/{device_id}/status` - Device status updates
- `alerts/{level}` - Alert messages
- `system/{component}` - System messages

## Security Notes
- Currently configured for anonymous access (development mode)
- For production, consider adding authentication
- Use firewall rules to restrict external access if needed
- Consider using SSL/TLS for secure connections

## Testing Connection
```bash
# Test publish
mosquitto_pub -h localhost -p 1883 -t "test/connection" -m "Connection test"

# Test subscribe (in another terminal)
mosquitto_sub -h localhost -p 1883 -t "test/#" -v
```
