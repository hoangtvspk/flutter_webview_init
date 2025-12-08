import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

enableStoragePermision() async {
  try {
    if (Platform.isIOS) {
      bool permissionGiven = await Permission.storage.isGranted;
      if (!permissionGiven) {
        permissionGiven = (await Permission.storage.request()).isGranted;
        return permissionGiven;
      }
      return permissionGiven;
    }
    final deviceInfoPlugin = DeviceInfoPlugin();
    final androidDeviceInfo = await deviceInfoPlugin.androidInfo;

    if (androidDeviceInfo.version.sdkInt < 33) {
      bool permissionGiven = await Permission.storage.isGranted;
      if (!permissionGiven) {
        permissionGiven = (await Permission.storage.request()).isGranted;
        return permissionGiven;
      }

      return permissionGiven;
    } else {
      return true;
    }
  } on Exception catch (e) {
    print(e);
  }
}

Future<void> activeRequestPermissionFCM() async {
  NotificationSettings settings;
  settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("====== Active FCM: AuthorizationStatus.authorized ======");
  } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
    settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print("====== Active FCM: AuthorizationStatus.denied ======");
  }
}
