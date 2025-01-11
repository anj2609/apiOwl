import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
AndroidDeviceInfo? _androidInfo;

Future<AndroidDeviceInfo> get androidInfo async {
  _androidInfo ??= await DeviceInfoPlugin().androidInfo;
  return _androidInfo!;
}

Future<void> startForegroundService(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    await service.setForegroundNotificationInfo(
      title: "APIOwl",
      content: "Running in background",
    );
    await service.setAsForegroundService();
  }
}

Future<void> setupNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'api_call_channel', 
    'API Call Notifications', 
    description: 'Notifications for API call results', 
    importance: Importance.defaultImportance,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> requestNotificationPermission() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    final info = await androidInfo;
    if (info.version.sdkInt >= 33) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final permission = await Permission.notification.request();
        if (permission != PermissionStatus.granted) {
          log("Notification permission denied");
          throw 'Notification permission required';
        }
      }
    }
  } catch (e) {
    log("Permission error: $e");
    rethrow;
  }
}

Future<void> initializeService() async {
  await androidInfo; 
  final service = FlutterBackgroundService();
  
  
  await setupNotificationChannel();
  
  await service.configure(
    iosConfiguration: IosConfiguration(),
    androidConfiguration: AndroidConfiguration(
      autoStart: true,
      onStart: onStart,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
      initialNotificationTitle: "APIOwl Service",
      initialNotificationContent: "Active",
    ),
  );

  if (!(await service.isRunning())) {
    await requestNotificationPermission();
    log("Starting service");
    await service.startService();
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  log("Service onStart triggered");

  if (service is AndroidServiceInstance) {
    try {
      await service.setForegroundNotificationInfo(
        title: "APIOwl Service",
        content: "Active",
      );

      service.on('setAsForeground').listen((event) async {
        log("Setting service as foreground");
        await startForegroundService(service);
      });

      service.on('setAsBackground').listen((event) async {
        log("Setting service as background");
        service.setAsBackgroundService();
      });

      service.on('stopService').listen((event) async {
        log("Stop service requested");
        try {
          await flutterLocalNotificationsPlugin.cancelAll();
          log("Notifications cancelled");
          
          Timer.run(() {
            service.stopSelf();
            log("Service stopped successfully");
          });
        } catch (e) {
          log("Error stopping service: $e");
        }
      });
    } catch (e) {
      log('Error starting foreground service: $e');
      return;
    }
  }

  await _initializeService(service);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String apiUrl = prefs.getString('api_url') ?? '';
  int interval = prefs.getInt('interval') ?? 0;

  if (apiUrl.isNotEmpty && interval > 0) {
    Timer.periodic(Duration(minutes: interval), (timer) async {
      final isRunning = prefs.getBool('service_running') ?? false;
      if (!isRunning) {
        timer.cancel();
      } else {
        log("Making API call");
        await makeApiCall(apiUrl);
      }
    });
  }
}

Future<void> _initializeService(ServiceInstance service) async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> makeApiCall(String apiUrl) async {
  try {
    final response = await http.post(Uri.parse(apiUrl));
    log(response.body);
    log(apiUrl);
    if (response.statusCode == 200) {
      // print('API Call Success: Data fetched successfully');
      await showNotification('APIOWL', 'API HIT SUCCESS');
    } else {
      // print('API Called');
      log(apiUrl);
      await showNotification('APIOWL', 'API HIT SUCCESS');
    }
  } catch (e) {
    // print('Error: Error occurred while calling API');
    await showNotification('Error', 'Error occurred while calling API: $e');
  }
}

Future<void> showNotification(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'api_call_channel', 
    'API Call Notifications', 
    channelDescription: 'Notifications for API call results',
    importance: Importance.low,
    priority: Priority.low,
    playSound: false,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    0, 
    title, 
    body, 
    platformChannelSpecifics,
  );
}

bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}