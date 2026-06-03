import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/app_data_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'ble_service.dart';
import 'tremor_pipeline.dart';
import 'gait_pipeline.dart';
import 'gait_inference.dart';
import 'phone_sensor_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Initialise processing pipelines
  final ble   = BleService();
  final phone = PhoneSensorService();
  final engine = GaitInferenceEngine();

  final gait = GaitPipeline(
    ble:    ble,
    phone:  phone,
    engine: engine,
  );

  final tremor = TremorPipeline(ble: ble);

  // Initialise gait engine (loads ML model)
  await gait.init();

  // Start streaming
  await ble.start();
  tremor.start();
  await gait.start();

  runApp(ParkinsonsTrackerApp(
    bleService:      ble,
    tremorPipeline:  tremor,
    gaitPipeline:    gait,
  ));
}

class ParkinsonsTrackerApp extends StatelessWidget {
  final BleService     bleService;
  final TremorPipeline tremorPipeline;
  final GaitPipeline   gaitPipeline;

  const ParkinsonsTrackerApp({
    super.key,
    required this.bleService,
    required this.tremorPipeline,
    required this.gaitPipeline,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: bleService),
        ChangeNotifierProvider.value(value: tremorPipeline),
        ChangeNotifierProvider.value(value: gaitPipeline),
        ChangeNotifierProvider(
          create: (_) => AppDataService(
            bleService:     bleService,
            tremorPipeline: tremorPipeline,
            gaitPipeline:   gaitPipeline,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Parkinson\'s Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const LoginScreen(),
      ),
    );
  }
}