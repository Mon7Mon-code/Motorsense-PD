import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arduino BLE Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BLEHomePage(),
    );
  }
}

class BLEHomePage extends StatefulWidget {
  const BLEHomePage({super.key});

  @override
  State<BLEHomePage> createState() => _BLEHomePageState();
}

class _BLEHomePageState extends State<BLEHomePage> {
  // BLE variables
  BluetoothDevice? connectedDevice;
  List<BluetoothDevice> devicesList = [];
  bool isScanning = false;

  // Data variables
  String receivedData = "No data yet";
  List<String> dataHistory = [];

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  // Request Bluetooth permissions
  Future<void> requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  // Scan for BLE devices
  Future<void> startScan() async {
    setState(() {
      isScanning = true;
      devicesList.clear();
    });

    // Start scanning
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (!devicesList.contains(result.device)) {
          setState(() {
            devicesList.add(result.device);
          });
        }
      }
    });

    // Wait for scan to complete
    await Future.delayed(const Duration(seconds: 4));
    await FlutterBluePlus.stopScan();

    setState(() {
      isScanning = false;
    });
  }

  // Connect to a device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        connectedDevice = device;
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find the service and characteristic you want to read from
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          // Subscribe to notifications (Arduino sends data)
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.lastValueStream.listen((value) {
              // Convert bytes to string
              String csvData = String.fromCharCodes(value);
              setState(() {
                receivedData = csvData;
                dataHistory.insert(0, csvData);
                if (dataHistory.length > 50) {
                  dataHistory.removeLast(); // Keep only last 50 readings
                }
              });
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error connecting: $e");
    }
  }

  // Disconnect from device
  Future<void> disconnectDevice() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      setState(() {
        connectedDevice = null;
        receivedData = "Disconnected";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Arduino BLE Reader'),
      ),
      body: Column(
        children: [
          // Connection status
          Container(
            padding: const EdgeInsets.all(16),
            color: connectedDevice != null
                ? Colors.green[100]
                : Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  connectedDevice != null
                      ? 'Connected to: ${connectedDevice!.platformName}'
                      : 'Not connected',
                  style: const TextStyle(fontSize: 16),
                ),
                if (connectedDevice != null)
                  ElevatedButton(
                    onPressed: disconnectDevice,
                    child: const Text('Disconnect'),
                  ),
              ],
            ),
          ),

          // Current data display
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest Data:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  receivedData,
                  style: const TextStyle(fontSize: 24, color: Colors.blue),
                ),
              ],
            ),
          ),

          // Data history
          Expanded(
            child: connectedDevice == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Scan for devices to get started'),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: isScanning ? null : startScan,
                          icon: isScanning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.bluetooth_searching),
                          label: Text(
                            isScanning ? 'Scanning...' : 'Scan for Devices',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Device list
                        if (devicesList.isNotEmpty)
                          Expanded(
                            child: ListView.builder(
                              itemCount: devicesList.length,
                              itemBuilder: (context, index) {
                                final device = devicesList[index];
                                return ListTile(
                                  title: Text(
                                    device.platformName.isNotEmpty
                                        ? device.platformName
                                        : 'Unknown Device',
                                  ),
                                  subtitle: Text(device.remoteId.toString()),
                                  trailing: ElevatedButton(
                                    onPressed: () => connectToDevice(device),
                                    child: const Text('Connect'),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: dataHistory.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(dataHistory[index]),
                        subtitle: Text('Reading ${index + 1}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    disconnectDevice();
    super.dispose();
  }
}
