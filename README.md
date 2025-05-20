# 💧 Waterio (ESP32 + Flutter)

A **Waterio** system designed using **ESP32**, **Load Cell**, and a **Flutter** mobile app. This educational and practical project demonstrates IoT integration for tracking hydration by calculating the number of **sips** consumed through real-time weight sensing and Bluetooth communication.


## 🚀 Features

* Sip Detection Using Load Cell
* Real-Time Weight Monitoring
* Bluetooth Communication (ESP32 ↔ Flutter App)
* Mobile UI for Live Tracking
* Daily Hydration Goal Tracking
* Clean Code with Modular Architecture (ESP + App)


## 🧱 Tech Stack

* **Microcontroller**: ESP32  
* **Sensor**: HX711 with Load Cell  
* **Mobile App**: Flutter  
* **Communication**: Bluetooth (BLE)  
* **IDE**: VS Code / Arduino IDE (ESP32), Android Studio (Flutter)


## 📂 System Components

1. **Load Cell + HX711**

   * Measures weight changes in real time
   * Detects weight difference before and after sips

2. **ESP32 Firmware**

   * Reads weight data from HX711
   * Calculates and filters sips (weight thresholds)
   * Sends data to Flutter app via Bluetooth

3. **Flutter Mobile App**

   * Connects to ESP32 over BLE
   * Displays live sip count and bottle weight
   * Provides hydration stats and daily goals


## 📉 Sip Detection Logic

* A **sip** is registered when a weight drop exceeding a threshold (e.g., >15g) is detected and then stabilizes.
* Anti-noise filtering ensures accurate sip counting.
* Daily total sips and water consumed are logged and displayed.


## 🖼️ System Screenshots

![App UI](https://github.com/user-attachments/assets/smart-bottle-app-screenshot.png)

![Circuit Diagram](https://github.com/user-attachments/assets/4fda9cf7-b404-4c11-8b6a-18f5ed7d9827)


## ⚙️ How to Run

### 🔌 ESP32 Setup

1. **Wiring**

   * Connect Load Cell to HX711
   * Connect HX711 to ESP32 (e.g., DOUT → GPIO 4, SCK → GPIO 5)

2. **Flash Firmware**

   * Open the firmware in Arduino IDE or VS Code (PlatformIO)
   * Upload to ESP32

### 📱 Flutter App Setup

1. **Clone the Repository**

   ```bash
   git clone https://github.com/okhadragy/WaterIO.git
   cd WaterIO/flutter-app
   ```

2. **Run on Device**

   * Open in Android Studio
   * Connect phone and run the app
   * Pair with ESP32 via Bluetooth


## 📜 License

This project is open-source and available under the **MIT License**.
