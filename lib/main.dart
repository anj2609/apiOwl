import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'service.dart';  
import 'api_caller_screen.dart';  
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:developer';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await requestNotificationPermission();
  await initializeService();
  runApp(const MyApp());
}
Future<void> requestNotificationPermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      final permission = await Permission.notification.request();
      if (permission != PermissionStatus.granted) {
        log("Notification permission denied");
        throw Exception("Notification permission is required.");
      }
    }
  }
}
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

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
