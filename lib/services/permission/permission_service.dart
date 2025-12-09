import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling app permissions
/// Centralizes all permission-related business logic
class PermissionService {
  // ==================== Storage Permission ====================

  /// Request storage permission for file downloads
  /// Returns true if permission is granted, false otherwise
  ///
  /// Note: Android 13+ (SDK 33+) doesn't require storage permission
  /// for app-specific directories
  Future<bool> requestStoragePermission() async {
    try {
      if (Platform.isIOS) {
        final isGranted = await Permission.storage.isGranted;
        if (!isGranted) {
          final status = await Permission.storage.request();
          return status.isGranted;
        }
        return isGranted;
      }

      // Android
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidDeviceInfo = await deviceInfoPlugin.androidInfo;

      // Android 13+ (SDK 33+) doesn't require storage permission
      // for app-specific directories
      if (androidDeviceInfo.version.sdkInt >= 33) {
        return true;
      }

      // Android < 13 requires storage permission
      final isGranted = await Permission.storage.isGranted;
      if (!isGranted) {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
      return isGranted;
    } catch (e) {
      print('Error requesting storage permission: $e');
      return false;
    }
  }

  // ==================== Notification Permission ====================

  /// Request FCM notification permission
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestNotificationPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print("FCM Permission: Authorized");
        return true;
      }

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print("FCM Permission: Denied - requesting again");
        // Try once more
        final retrySettings =
            await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        return retrySettings.authorizationStatus ==
            AuthorizationStatus.authorized;
      }

      // Provisional or other status
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  // ==================== Utility Methods ====================

  /// Check if storage permission is granted
  Future<bool> isStoragePermissionGranted() async {
    try {
      if (Platform.isIOS) {
        return await Permission.storage.isGranted;
      }

      // Android 13+ doesn't require storage permission
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidDeviceInfo = await deviceInfoPlugin.androidInfo;
      if (androidDeviceInfo.version.sdkInt >= 33) {
        return true;
      }

      return await Permission.storage.isGranted;
    } catch (e) {
      print('Error checking storage permission: $e');
      return false;
    }
  }

  /// Open app settings for manual permission grant
  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}

// ==================== Legacy Functions (Deprecated) ====================
// These functions are kept for backward compatibility
// Consider migrating to PermissionService

@Deprecated('Use PermissionService.requestStoragePermission() instead')
Future<bool?> enableStoragePermision() async {
  final service = PermissionService();
  return await service.requestStoragePermission();
}

@Deprecated('Use PermissionService.requestNotificationPermission() instead')
Future<void> activeRequestPermissionFCM() async {
  final service = PermissionService();
  await service.requestNotificationPermission();
}
