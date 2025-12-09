import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_base/constants/javascript.dart';
import 'package:webview_base/firebase_options.dart';
import 'package:webview_base/firebase_options_dev.dart';
import 'package:webview_base/firebase_options_staging.dart';
import 'package:webview_base/provider/webview_provider.dart';

class FirebaseConfig {
  FirebaseConfig._internal();
  static final FirebaseConfig instance = FirebaseConfig._internal();

  factory FirebaseConfig() {
    return instance;
  }

  late AndroidNotificationChannel channel;
  bool isFlutterLocalNotificationsInitialized = false;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  String? messId;

  /// Initialize Firebase app with environment-specific options
  static Future<void> initializeFirebaseApp(String environment) async {
    await Firebase.initializeApp(
      name: environment,
      options: environment == 'dev'
          ? DefaultFirebaseDevOptions.currentPlatform
          : environment == 'staging'
              ? DefaultFirebaseStagingOptions.currentPlatform
              : DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase app initialized with environment: $environment');
    print(
        'Firebase app options  $environment => ${Firebase.app().options.appId}');
  }

  /// Initialize Firebase messaging and notifications
  Future<void> initialize(BuildContext context) async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (context.mounted) {
        showFlutterNotification(context, message);
      }
    });
    if (context.mounted) {
      await setupInteractedMessage(context);
    }
    if (context.mounted) {
      await setupFlutterNotifications(context);
    }
  }

  /// Setup message interaction handlers
  Future<void> setupInteractedMessage(BuildContext context) async {
    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    // If the message also contains a data property with a "type" of "chat",
    // navigate to a chat screen
    if (initialMessage != null) {
      saveDeepLink(initialMessage);
    }

    // Also handle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (context.mounted) {
        onMessageOpenApp(context, message);
      }
    });
  }

  /// Handle message when app is opened from background
  void onMessageOpenApp(BuildContext context, RemoteMessage message) async {
    try {
      final provider = Provider.of<WebViewProvider>(context, listen: false);
      InAppWebViewController? webViewController = provider.controller;
      if (webViewController == null) {
        saveDeepLink(message);
      } else {
        if (message.data['redirectUrl'] != null) {
          webViewController.evaluateJavascript(
              source: navigate(message.data['redirectUrl']));
        }
      }
    } catch (e) {
      print("webViewController error => $e");
    }
  }

  /// Save deep link from message
  void saveDeepLink(RemoteMessage message) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    if (message.data['redirectUrl'] != null) {
      pref.setString("deepLink", message.data['redirectUrl']);
    }
  }

  /// Setup Flutter local notifications
  Future<void> setupFlutterNotifications(BuildContext context) async {
    if (Platform.isIOS) {
      // Request permission for iOS notifications
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print('User granted permission: ${settings.authorizationStatus}');
      await FirebaseMessaging.instance.getAPNSToken();
    }

    channel = const AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings();

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: iosInitializationSettings);

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        handleNotificationTap(context, response);
      },
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    isFlutterLocalNotificationsInitialized = true;
  }

  /// Handle notification tap
  void handleNotificationTap(
      BuildContext context, NotificationResponse response) {
    if (response.payload != null) {
      // Handle the action, like navigating to a specific screen
      print('Notification payload: ${response.payload}');
      try {
        final provider = Provider.of<WebViewProvider>(context, listen: false);
        provider.handleNotification(response.payload ?? '');
      } catch (e) {
        print("err => $e");
      }
      // Navigate to a specific screen or perform some action based on the payload
    }
  }

  /// Show Flutter notification
  void showFlutterNotification(
      BuildContext context, RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    if (messId == message.messageId) {
      return;
    }
    if (notification != null) {
      print('show notification');

      // Only show notification using flutter_local_notifications on Android
      // iOS will handle foreground notifications natively via setForegroundNotificationPresentationOptions
      if (Platform.isAndroid) {
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
                android: AndroidNotificationDetails(channel.id, channel.name,
                    channelDescription: channel.description,
                    icon: 'ic_noti_icon',
                    color: const Color(0xff2E2C2C))),
            payload: message.data['redirectUrl']);
      }
      messId = message.messageId;
    }
  }
}
