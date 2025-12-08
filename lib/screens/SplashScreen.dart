import 'dart:async';
import 'dart:io';
import 'package:webview_base/config/env_config.dart';
import 'package:webview_base/helpers/Themes.dart';
import 'package:webview_base/provider/appGlobalKey.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import 'MainScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    startTimer();
  }

  // check update required when the version from Firebase Remote Config is greater than the current version
  Future<bool> checkUpdateRequired() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      final current = Version.parse(currentVersion);
      return false;
    } catch (e) {
      print(e);
      return false;
    }
  }

  // check show dev tool button when the version from Firebase Remote Config is less than the current version
  Future<bool> checkShowDevToolButton() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      final current = Version.parse(currentVersion);
      return false;
    } catch (e) {
      print(e);
      return true;
    }
  }

  startTimer() async {
    var duration = const Duration(seconds: 3);
    SharedPreferences pref = await SharedPreferences.getInstance();
    return Timer(duration, () async {
      bool isUpdateRequired = false;
      try {
        isUpdateRequired = await checkUpdateRequired();
        await FirebaseMessaging.instance.getAPNSToken();
        var fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken != null && pref.getString("fcmToken") == null) {
          pref.setString("fcmToken", fcmToken);
        }

        print('--------fcmToken:$fcmToken');
      } on Exception catch (e) {
        print("get fcm err : =>>> $e");
      }
      if (isUpdateRequired) {
        showUpdateDialog(context);
        return;
      }
      bool showDevToolButton = await checkShowDevToolButton();
      navigatorKey.currentState!.pushReplacement(MaterialPageRoute(
          builder: (_) => MyHomePage(
              webUrl: EnvConfig.instance.webviewUrl,
              showDevToolButton: showDevToolButton)));
    });
  }

  static Future<void> showUpdateDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('앱 업데이트 필요!'),
          content: Text(
            "EasySales의 새로운 버전이 출시되었습니다!\n지금 바로 업데이트하세요!",
            style: TextStyle(fontSize: 13),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                '지금 업데이트',
                style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 16),
              ),
              onPressed: () async {
                PackageInfo packageInfo = await PackageInfo.fromPlatform();
                final Uri iosAppStoreUrl =
                    Uri.parse("https://apps.apple.com/app/id6738642810");
                final Uri androidPlayStoreUrl = Uri.parse(
                    "https://play.google.com/store/apps/details?id=${packageInfo.packageName}");
                if (Platform.isAndroid) {
                  if (await canLaunchUrl(androidPlayStoreUrl)) {
                    launchUrl(androidPlayStoreUrl);
                  }
                  return;
                }
                launchUrl(iosAppStoreUrl);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark));
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      decoration: const BoxDecoration(
          image: DecorationImage(
              image: AssetImage('assets/images/splash_background.png'),
              fit: BoxFit.fill)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: perWidth(context, 24),
                vertical: perHeight(context, 168)),
            child: Image.asset(
              'assets/images/splash_content.png',
            ),
          )
        ])),
      ),
    );
  }
}
