import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_base/config/env_config.dart';
import 'package:webview_base/provider/appGlobalKey.dart';
import 'package:webview_base/provider/webviewURLProvider.dart';

import '../provider/navigationBarProvider.dart';
import 'constants/common.dart';
import 'constants/javascript.dart';
import 'provider/savedCookieProvider.dart';
import 'provider/themeProvider.dart';
import 'provider/webViewControllerProvider.dart';
import 'screens/SplashScreen.dart';
import 'services/cookies/cookiesServices.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback((_) async {
      // Only request tracking authorization on iOS, not Android
      if (Platform.isIOS) {
        final status =
            await AppTrackingTransparency.requestTrackingAuthorization();
        print("status => $status");
      }
    });
    const environment =
        String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');

    print('environment => $environment');
    await EnvConfig.initialize(environment);
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );
    // await RemoteConfigManager().initialize();
    // await activeRequestPermissionFCM();
  } on Exception catch (e) {
    print(e);
  }

  return runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<NavigationBarProvider>(
          create: (_) => NavigationBarProvider()),
      ChangeNotifierProvider(create: (context) => WebviewURLProvider()),
      ChangeNotifierProvider(create: (context) => WebViewControllerProvider()),
      ChangeNotifierProvider(create: (context) => SavedCookieProvider())
    ],
    builder: ((providerContext, child) {
      return MyApp();
    }),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? initialMessage;
  late SharedPreferences pref;
  String? messId;
  @override
  void initState() {
    super.initState();
    try {
      // FirebaseMessaging.onBackgroundMessage(
      //     _firebaseMessagingBackgroundHandler);

      setupInteractedMessage();
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        showFlutterNotification(message);
      });
      setupFlutterNotifications(context);
      checkExistCookie(context);
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> setupInteractedMessage() async {
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
      onMessageOpenApp(message);
    });
  }

  void onMessageOpenApp(RemoteMessage message) async {
    try {
      final provider =
          Provider.of<WebViewControllerProvider>(context, listen: false);
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

  void saveDeepLink(RemoteMessage message) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    if (message.data['redirectUrl'] != null) {
      pref.setString("deepLink", message.data['redirectUrl']);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: AppThemes.lightTheme,
        navigatorKey: navigatorKey,
        onGenerateRoute: null,
        home: SplashScreen());
  }

  @pragma('vm:entry-point')
  Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {}

  late AndroidNotificationChannel channel;

  bool isFlutterLocalNotificationsInitialized = false;

// request permission

// show android notification in-app

  void handleNotificationTap(
      BuildContext context, NotificationResponse response) {
    if (response.payload != null) {
      // Handle the action, like navigating to a specific screen
      print('Notification payload: ${response.payload}');
      try {
        final provider =
            Provider.of<WebViewControllerProvider>(context, listen: false);
        provider.handleNotification(response.payload ?? '');
      } catch (e) {
        print("err => $e");
      }
      // Navigate to a specific screen or perform some action based on the payload
    }
  }

  Future<void> setupFlutterNotifications(BuildContext context) async {
    if (Platform.isIOS) {
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
      alert: false,
      badge: true,
      sound: false,
    );
    isFlutterLocalNotificationsInitialized = true;
  }

  void showFlutterNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    if (messId == message.messageId) {
      return;
    }
    final provider =
        Provider.of<WebViewControllerProvider>(context, listen: false);
    InAppWebViewController? webViewController = provider.controller;
    WebUri? webUri = await webViewController?.getUrl();
    Uri? uri = webUri?.uriValue;
    if (notification != null &&
        Uri.parse(message.data['redirectUrl']).queryParameters['id'] !=
            uri?.queryParameters['id']) {
      flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
              android: AndroidNotificationDetails(channel.id, channel.name,
                  channelDescription: channel.description,
                  icon: '@drawable/ic_stat_onesignal_default',
                  color: Color(0xff02D3AE)),
              iOS: DarwinNotificationDetails()),
          payload: message.data['redirectUrl']);
      messId = message.messageId;
    }
  }

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
}
