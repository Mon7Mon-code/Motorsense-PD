import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsons_tracker/main.dart';
import 'package:parkinsons_tracker/ble_service.dart';
import 'package:parkinsons_tracker/tremor_pipeline.dart';
import 'package:parkinsons_tracker/gait_pipeline.dart';
import 'package:parkinsons_tracker/gait_inference.dart';
import 'package:parkinsons_tracker/phone_sensor_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final ble    = BleService();
    final phone  = PhoneSensorService();
    final engine = GaitInferenceEngine();
    final gait   = GaitPipeline(ble: ble, phone: phone, engine: engine);
    final tremor = TremorPipeline(ble: ble);

    await tester.pumpWidget(ParkinsonsTrackerApp(
      bleService:     ble,
      tremorPipeline: tremor,
      gaitPipeline:   gait,
    ));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
