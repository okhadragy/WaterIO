#include <BluetoothSerial.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include "HX711.h"

BluetoothSerial SerialBT;
#define LED_PIN 2  // D22 pin on ESP32

// HX711 circuit wiring
#define DOUT 12
#define CLK 13
HX711 scale;
float previousReading = 0;
float lastBottleDetected = 0;
bool bounce = 0;
float threshold = 50000;
const unsigned long debounceTime = 1000;
unsigned long lastChangeTime = 0;


void readTask(void *pvParameters) {
  while (true) {
    if (SerialBT.available()) {
      String message = SerialBT.readString();
      Serial.print(message);
      String part = "";
      for (int i = 0; i < message.length(); i++) {
        if (message[i] == '\n' || i == message.length() - 1) {
          if (part == "on") {
            digitalWrite(LED_PIN, HIGH);
            delay(500);
          } else if (part == "off") {
            digitalWrite(LED_PIN, LOW);
            delay(500);
          }
          part = "";
          continue;
        }
        part += message[i];
      }
    }
    vTaskDelay(20 / portTICK_PERIOD_MS);  // delay to yield control
  }
}

void writeTask(void *pvParameters) {
  while (true) {
    if (scale.is_ready()) {
      float currentReading = scale.get_units(20);  // average 10 readings
      Serial.print("Current Weight: ");
      Serial.println(currentReading, 2);
      Serial.print("Change: ");
      Serial.println(abs(currentReading - previousReading), 2);
      Serial.print("Last Time: ");
      Serial.println(lastChangeTime);
      Serial.print("Time: ");
      Serial.println(millis());
      Serial.print("Bounce: ");
      Serial.println(bounce);


      if (millis() - lastChangeTime > debounceTime && abs(currentReading - previousReading) > threshold){
        if (bounce){
          Serial.print("Weight DECREASE detected! Change: ");
          SerialBT.println("Sip");
        }
        bounce^=1;
        lastBottleDetected = currentReading;
        lastChangeTime = millis();
        delay(500);
      }

      previousReading = currentReading;
    } else {
      Serial.println("HX711 not found.");
    }
    vTaskDelay(1000 / portTICK_PERIOD_MS);  // send every second
  }
}
void setup() {
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(115200);
  SerialBT.begin("ESP32test");  //Bluetooth device name
  scale.begin(DOUT, CLK);
  scale.set_scale(-1);  // Set this after calibration
  scale.tare();         // Reset the scale to 0
  xTaskCreate(readTask, "Read Task", 2048, NULL, 1, NULL);
  xTaskCreate(writeTask, "Write Task", 2048, NULL, 1, NULL);
  delay(1000);
  Serial.println("The device started, now you can pair it with bluetooth!");
}

void loop() {
}
