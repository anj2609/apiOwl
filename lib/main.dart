import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'service.dart';
import 'api_caller_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:developer';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import "package:flutter/services.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // print(
  //     await DisableBatteryOptimization.isBatteryOptimizationDisabled ?? false);
  // while (
  //     await DisableBatteryOptimization.isBatteryOptimizationDisabled ?? false) {
  //   await Future.delayed(const Duration(seconds: 1));
  //   print("Battery optimization is disabled");
  //   await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
  // }
  // print(
  //     await DisableBatteryOptimization.isBatteryOptimizationDisabled ?? false);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await requestNotificationPermission();
  await initializeService();
  runApp(const MyApp());
}

Future<void> requestNotificationPermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      // Request notification permission
      final notificationPermission = await Permission.notification.request();
      if (notificationPermission != PermissionStatus.granted) {
        log("Notification permission denied");
        throw Exception("Notification permission is required.");
      }

  
      if (!await Permission.scheduleExactAlarm.isGranted) {
        final alarmPermission = await Permission.scheduleExactAlarm.request();
        if (alarmPermission != PermissionStatus.granted) {
          log("Exact alarm permission denied");
          throw Exception("Exact alarm permission is required.");
        }
      }
    }
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Caller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ApiCallerScreen(),
    );
  }
}
