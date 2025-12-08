import 'dart:io';
import 'package:flutter/services.dart';

class AppEnvironment {
  static const MethodChannel _platform = MethodChannel('app/environment');
  static const String buildType =
      String.fromEnvironment("BUILD_TYPE", defaultValue: "production");

  // Checks if the app is in debug mode
  static bool isDebugMode() {
    return !const bool.fromEnvironment("dart.vm.product");
  }

  // Checks if the app is running on TestFlight (iOS only)
  static Future<bool> isTestFlight() async {
    if (!Platform.isIOS) return false; // TestFlight is only applicable to iOS

    try {
      final bool result = await _platform.invokeMethod('isTestFlight');
      return result;
    } catch (e) {
      return false; // Default to false if any error occurs
    }
  }

  // Checks if the app is running in a testing environment
  static Future<bool> isTestingEnvironment() async {
    if (isDebugMode()) {
      return true; // Debug mode is considered testing
    }

    if (Platform.isIOS) {
      return await isTestFlight();
    } else if (Platform.isAndroid) {
      return buildType == "testing";
    }

    // Additional logic for Android testing tracks can be added here if needed
    return false;
  }
}
