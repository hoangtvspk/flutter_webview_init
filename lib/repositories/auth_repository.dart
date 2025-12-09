import 'dart:convert';

import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_base/config/env_config.dart';
import 'package:webview_base/models/user_info.dart';
import 'package:webview_base/services/cookies/cookies_services.dart';
import 'package:webview_base/services/rest_api/fcm_service.dart';

/// Repository for user authentication and session management
/// Handles user login state, FCM tokens, and cookie-based authentication
class AuthRepository {
  final env = EnvConfig.instance;

  // ==================== FCM Token Management ====================

  /// Save FCM device token to backend
  ///
  /// Parameters:
  /// - [fcmToken]: The Firebase Cloud Messaging token
  /// - [uidx]: Optional user ID to associate with the token
  Future<void> saveDeviceToken({
    required String fcmToken,
    String? uidx,
  }) async {
    final payload = uidx != null
        ? {"token": fcmToken, "userId": uidx}
        : {"token": fcmToken, "userId": null};
    await FcmService().save(payload);
  }

  /// Delete FCM device token from backend
  /// Called when user logs out or token needs to be removed
  Future<void> deleteDeviceToken({required String fcmToken}) async {
    await FcmService().delete(fcmToken);
  }

  // ==================== User Authentication ====================

  /// Check if user is logged in via website cookie
  /// Manages FCM token registration based on login status
  ///
  /// This method:
  /// 1. Checks for user cookie in the WebView
  /// 2. If user was logged in but cookie is gone → handles logout
  /// 3. If user is logged in → registers FCM token with user ID
  ///
  /// Parameters:
  /// - [cookieManager]: The WebView cookie manager
  /// - [url]: The website URL to check cookies for
  /// - [name]: The name of the user cookie (e.g., "USER_INFOR")
  Future<void> checkUserLoginStatus({
    required CookieManager cookieManager,
    required String url,
    required String name,
  }) async {
    String? myDeviceToken = await getFcmToken();
    if (myDeviceToken == null) return;

    Cookie? cookie = await cookieManager.getCookie(
        url: WebUri.uri(Uri.parse(url)), name: name);
    SharedPreferences pref = await SharedPreferences.getInstance();
    // User was logged in but cookie is now gone (logged out)
    if (pref.get("loginStatus${env.env}") == "logged-in" && cookie == null) {
      await handleLogout(fcmToken: myDeviceToken);
      return;
    }
    // User is logged in
    else if (cookie != null) {
      await handleLogin(
        cookie: cookie,
        fcmToken: myDeviceToken,
        url: url,
      );
    }
  }

  /// Handle user logout
  /// Removes FCM token, clears badge, and updates login status
  Future<void> handleLogout({required String fcmToken}) async {
    SharedPreferences pref = await SharedPreferences.getInstance();

    await deleteDeviceToken(fcmToken: fcmToken);

    FlutterAppBadgeControl.isAppBadgeSupported().then((value) {
      FlutterAppBadgeControl.removeBadge();
    });

    pref.setString("loginStatus${env.env}", "logged-out");
    pref.remove('cookies');
  }

  /// Handle user login
  /// Registers FCM token with user ID and saves cookies
  Future<void> handleLogin({
    required Cookie cookie,
    required String fcmToken,
    required String url,
  }) async {
    SharedPreferences pref = await SharedPreferences.getInstance();

    String decodedString = Uri.decodeComponent(cookie.value);
    Map<String, dynamic> jsonData = jsonDecode(decodedString);
    UserInfo user = UserInfo.fromJson(jsonData);

    // Save FCM token with userId into database
    await saveDeviceToken(fcmToken: fcmToken, uidx: user.id);
    pref.setString("loginStatus${env.env}", "logged-in");

    // Handle saving cookie issue on iOS
    await saveCookies(url);
  }

  /// Get current login status
  Future<bool> isLoggedIn() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.get("loginStatus${env.env}") == "logged-in";
  }

  /// Set stored FCM token
  Future<void> setFcmToken({required String fcmToken}) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    if (pref.getString("fcmToken") == null) {
      pref.setString("fcmToken", fcmToken);
    }
  }

  /// Get stored FCM token
  Future<String?> getFcmToken() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString("fcmToken");
  }
}
