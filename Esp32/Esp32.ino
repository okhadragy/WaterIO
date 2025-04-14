#include <BluetoothSerial.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

BluetoothSerial SerialBT;
#define LED_PIN 4  // D22 pin on ESP32
int counter=0;

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
    vTaskDelay(20 / portTICK_PERIOD_MS); // delay to yield control
  }
}

void writeTask(void *pvParameters) {
  while (true) {
    if (counter % 10000 == 0) {
      SerialBT.println("Sip");
    }
    vTaskDelay(1000 / portTICK_PERIOD_MS); // send every second
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(115200);
  SerialBT.begin("ESP32test");  //Bluetooth device name
  xTaskCreate(readTask, "Read Task", 2048, NULL, 1, NULL);
  xTaskCreate(writeTask, "Write Task", 2048, NULL, 1, NULL);
  delay(1000);
  Serial.println("The device started, now you can pair it with bluetooth!");

}

void loop() {
}
