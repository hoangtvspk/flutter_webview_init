import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_base/config/env_config.dart';
import 'package:webview_base/config/firebase_config.dart';
import 'package:webview_base/provider/appGlobalKey.dart';
import 'package:webview_base/provider/webviewLoadingProvider.dart';
import 'package:webview_base/provider/webviewURLProvider.dart';
import 'package:webview_base/utils/permission.dart';

import '../provider/navigationBarProvider.dart';
import 'constants/common.dart';
import 'provider/savedCookieProvider.dart';
import 'provider/themeProvider.dart';
import 'provider/webViewControllerProvider.dart';
import 'screens/MainScreen.dart';
import 'services/cookies/cookiesServices.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.notification?.body}');
  // Handle background message here
}

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
    await EnvConfig.initialize(environment);
    await FirebaseConfig.initializeFirebaseApp(environment);

    // Register background message handler (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // await RemoteConfigManager().initialize();
    await activeRequestPermissionFCM();
  } on Exception catch (e) {
    print(e);
  }

  return runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<NavigationBarProvider>(
          create: (_) => NavigationBarProvider()),
      ChangeNotifierProvider(create: (context) => WebviewURLProvider()),
      ChangeNotifierProvider(create: (context) => WebViewControllerProvider()),
      ChangeNotifierProvider(create: (context) => SavedCookieProvider()),
      ChangeNotifierProvider(create: (context) => WebViewLoadingProvider())
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
  @override
  void initState() {
    super.initState();
    try {
      FirebaseConfig.instance.initialize(context);
      checkExistCookie(context);
    } on Exception catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    super.dispose();
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
        home: MyHomePage(
            webUrl: EnvConfig.instance.webviewUrl, showDevToolButton: false));
  }
}
