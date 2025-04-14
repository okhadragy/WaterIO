import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert'; // For ascii encoding/decoding

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('myBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cocalarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: const MyHomePage(title: 'Cocalarm'),
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
  late Box box;
  int totalSips = 0;
  int goalSips = 10;
  double percentageGoal = 0;
  bool ledOn = false;
  String username = "Erfan";
  BluetoothConnection? connection;
  bool isConnected = false;
  String buffer = '';

  @override
  void initState() {
    super.initState();
    box = Hive.box('myBox');
    totalSips = box.get('totalSips', defaultValue: 0);
    goalSips = box.get('goalSips', defaultValue: 10);
    username = box.get('username', defaultValue: "Erfan");
    percentageGoal = (totalSips / goalSips) * 100;
    checkPermissions(); // Check permissions on startup
  }

  void checkPermissions() async {
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

  void getPairedESP() async {
    final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
    if (isEnabled == null || !isEnabled) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }

    List<BluetoothDevice> pairedDevices =
        await FlutterBluetoothSerial.instance.getBondedDevices();
    BluetoothDevice? espDevice;
    for (BluetoothDevice device in pairedDevices) {
      if (device.name != null && device.name!.toLowerCase().contains("esp")) {
        espDevice = device;
        break;
      }
    }

    if (espDevice != null) {
      print("Found ESP32: ${espDevice.name} - ${espDevice.address}");
      try {
        connection = await BluetoothConnection.toAddress(espDevice.address);
        print('Connected to the ESP32!');
        setState(() {
          isConnected = true;
        });

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

  void reset() {
    box.put('totalSips', 0);
    setState(() {
      totalSips = 0;
      percentageGoal = 0;
    });
  }

  void incrementSips() {
    setState(() {
      totalSips++;
      percentageGoal = (totalSips / goalSips) * 100;
      box.put('totalSips', totalSips);
    });
    sendMessage("Sip");
  }

  void toggleLED() {
    if (isConnected) {
      setState(() {
        ledOn = !ledOn;
      });
      sendMessage(ledOn ? "on" : "off");
    }
  }

  void editUsername() {
    String newName = username;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Username'),
            content: TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Enter new name'),
              onChanged: (value) => newName = value,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    username = newName;
                    box.put('username', username);
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void editGoalSips() {
    String newGoal = goalSips.toString();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Goal Sips'),
            content: TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Enter new goal'),
              onChanged: (value) => newGoal = value,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  int? parsedGoal = int.tryParse(newGoal);
                  if (parsedGoal != null && parsedGoal > 0) {
                    setState(() {
                      goalSips = parsedGoal;
                      box.put('goalSips', goalSips);
                      percentageGoal = (totalSips / goalSips) * 100;
                    });
                  }
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(value, style: const TextStyle(color: Colors.blue)),
      ],
    );
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: [
            const ListTile(
              title: Text(
                'Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Edit Username'),
              onTap: () {
                Navigator.pop(context);
                editUsername();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('Edit Goal Sips'),
              onTap: () {
                Navigator.pop(context);
                editGoalSips();
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    children: [
                      const TextSpan(text: "What's up, "),
                      TextSpan(
                        text: username,
                        style: TextStyle(color: Colors.lightBlue.shade600),
                      ),
                      const TextSpan(text: "!"),
                    ],
                  ),
                ),
                Builder(
                  builder:
                      (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.lightBlue),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              totalSips == 0
                  ? 'You have no task for today!'
                  : 'You’ve logged $totalSips sips today!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.lightBlue.shade400,
              ),
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _infoRow('Base hydration', '$totalSips sips'),
                    const SizedBox(height: 10),
                    _infoRow('Daily goal', '$goalSips sips'),
                    const SizedBox(height: 10),
                    _infoRow(
                      'Progress',
                      '${percentageGoal.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                      const SizedBox(height: 24),
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
            ),
            const SizedBox(height: 16),
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
            ElevatedButton(
              onPressed: reset,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade400,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Reset Sips',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: incrementSips,
        backgroundColor: Colors.lightBlue,
        child: const Icon(Icons.add),
      ),
    );
  }
}
