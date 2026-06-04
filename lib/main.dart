import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/app_data_service.dart';
import 'services/local_storage_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/patient/patient_shell.dart';
import 'screens/patient/patient_onboarding_screen.dart';
import 'screens/clinician/clinician_shell.dart';
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

  final ble    = BleService();
  final phone  = PhoneSensorService();
  final engine = GaitInferenceEngine();

  final gait   = GaitPipeline(ble: ble, phone: phone, engine: engine);
  final tremor = TremorPipeline(ble: ble);

  final storage = await LocalStorageService.create();
  final appData = AppDataService(
    bleService:     ble,
    tremorPipeline: tremor,
    gaitPipeline:   gait,
    storage:        storage,
  );
  await appData.init();

  final home = _resolveInitialScreen(appData);

  // Show UI first — native ML/BLE init must not block cold start (release APK).
  runApp(ParkinsonsTrackerApp(
    bleService:     ble,
    tremorPipeline: tremor,
    gaitPipeline:   gait,
    appDataService: appData,
    home:           home,
  ));

  unawaited(_bootstrapPipelines(ble: ble, tremor: tremor, gait: gait));
}

Widget _resolveInitialScreen(AppDataService svc) {
  if (svc.currentUserId == null)     return const LoginScreen();
  if (svc.isClinicianMode)           return const ClinicianShell();
  if (svc.isOnboardingComplete)      return const PatientShell();
  return const PatientOnboardingScreen();
}

Future<void> _bootstrapPipelines({
  required BleService ble,
  required TremorPipeline tremor,
  required GaitPipeline gait,
}) async {
  try {
    await gait.init();
    await ble.start();
    tremor.start();
    await gait.start();
  } catch (e, st) {
    debugPrint('[main] Pipeline bootstrap failed: $e\n$st');
  }
}

class ParkinsonsTrackerApp extends StatelessWidget {
  final BleService      bleService;
  final TremorPipeline  tremorPipeline;
  final GaitPipeline    gaitPipeline;
  final AppDataService  appDataService;
  final Widget          home;

  const ParkinsonsTrackerApp({
    super.key,
    required this.bleService,
    required this.tremorPipeline,
    required this.gaitPipeline,
    required this.appDataService,
    required this.home,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: bleService),
        ChangeNotifierProvider.value(value: tremorPipeline),
        ChangeNotifierProvider.value(value: gaitPipeline),
        ChangeNotifierProvider.value(value: appDataService),
      ],
      child: MaterialApp(
        title: 'Parkinson\'s Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: home,
      ),
    );
  }
}
