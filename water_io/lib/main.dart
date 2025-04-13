import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water.io',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: const MyHomePage(title: 'Water.io'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Declare the variables
  int totalSips = 0; // Number of sips
  final int goalSips = 10; // Goal sips per day
  bool showSips = false; // Toggle button to show sips
  double percentageGoal = 0; // Percentage of goal reached
  bool ledOn = false; // LED status
  BluetoothConnection? connection;
  bool isConnected = false;
  String buffer = '';

  // Function to increment sips
  void incrementSips() {
    setState(() {
      totalSips++;
      percentageGoal = (totalSips / goalSips) * 100;
    });
    DateTime now = DateTime.now();
    String formattedDate = "${now.year}-${now.month}-${now.day}";
    String formattedTime = "${now.hour}:${now.minute}:${now.second}";
    print('Date received: $formattedDate Time: $formattedTime');
  }

  // Function to toggle sips visibility
  void toggleSips() {
    setState(() {
      showSips = !showSips;
    });
  }

  // Function to toggle LED status
  void toggleLED() {
    if (isConnected) {
      setState(() {
        ledOn = !ledOn;
      });
      sendMessage(ledOn ? "on" : "off");
    }
  }

  @override
  void initState() {
    super.initState();
    // Call getPairedESP() to try connecting to the ESP32
    checkPermissions();
  }

  // Function to get paired ESP32 device and connect
  void getPairedESP() async {
    // Ensure Bluetooth is enabled
    final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
    if (isEnabled == null || !isEnabled) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }

    // Get list of paired devices
    List<BluetoothDevice> pairedDevices =
        await FlutterBluetoothSerial.instance.getBondedDevices();

    // Filter ESP32 by name or address pattern (customize as needed)
    BluetoothDevice? espDevice;

    for (BluetoothDevice device in pairedDevices) {
      if (device.name != null && device.name!.toLowerCase().contains("esp")) {
        espDevice = device;
        break; // Exit loop when the ESP32 device is found
      }
    }

    if (espDevice != null) {
      print("Found ESP32: ${espDevice.name} - ${espDevice.address}");
      // Now connect
      try {
        connection = await BluetoothConnection.toAddress(espDevice.address);
        print('Connected to the ESP32!');
        setState(() {
          isConnected = true;
        });

        // Real-time listener
        connection!.input!
            .listen((data) {
              buffer += ascii.decode(data);

              int index;
              while ((index = buffer.indexOf('\n')) != -1) {
                final line = buffer.substring(0, index).trim();
                buffer = buffer.substring(index + 1);

                setState(() {
                  if (line == "Sip") incrementSips();
                });
              }
            })
            .onDone(() {
              print('Disconnected by ESP');
              setState(() {
                isConnected = false;
              });
            });
      } catch (e) {
        print('Connection failed: $e');
        setState(() {
          isConnected = false;
        });
      }
    } else {
      print("ESP32 not found in paired devices.");
    }
  }

  void sendMessage(String msg) {
    if (connection != null && isConnected) {
      connection!.output.add(ascii.encode(msg + "\n"));
      print('Sent: $msg');
    }
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  void checkPermissions() async {
    // Request Bluetooth permissions
    PermissionStatus bluetoothStatus = await Permission.bluetooth.request();
    PermissionStatus bluetoothConnectStatus =
        await Permission.bluetoothConnect.request();
    PermissionStatus locationStatus =
        await Permission.locationWhenInUse.request();
    PermissionStatus bluetoothScanStatus =
        await Permission.bluetoothScan.request();

    if (bluetoothStatus.isGranted &&
        bluetoothConnectStatus.isGranted &&
        locationStatus.isGranted &&
        bluetoothScanStatus.isGranted) {
      print("Permissions granted.");
      getPairedESP(); // Proceed with Bluetooth operations
    } else {
      print("Permissions denied.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Progress Section
            const Text(
              'Daily Hydration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Base hydration'),
                        Text(
                          '$totalSips sips',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('Daily goal:'), Text('10 sips')],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Progress:'),
                        Text(
                          '${percentageGoal.toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Progress Ring Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      height: 150,
                      width: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: percentageGoal / 100,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${percentageGoal.toStringAsFixed(1)}%",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$totalSips/$goalSips',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: incrementSips,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Drink More Water (Add Sip)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            ElevatedButton(
              onPressed: toggleLED,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    ledOn
                        ? Colors.red
                        : const Color.fromARGB(255, 50, 235, 120),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                ledOn ? 'LED Off' : 'LED On',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Hydration Tip Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Stay hydrated for better health!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
