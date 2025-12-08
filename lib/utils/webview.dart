import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:webview_base/constants/javascript.dart';
import 'package:webview_base/helpers/Themes.dart';
import 'package:webview_base/widgets/webview/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_base/services/rest_api/fcmApi.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env_config.dart';
import '../models/user_info.dart';
import '../provider/navigationBarProvider.dart';

class WebviewUtils {
  Future<bool> exitApp(
      {required BuildContext context,
      required bool mounted,
      required bool validURL,
      required InAppWebViewController? webViewController,
      required void Function() setState}) async {
    if (mounted) {
      context.read<NavigationBarProvider>().animationController.reverse();
    }
    if (!validURL) {
      return Future.value(true);
    }
    if (await webViewController!.canGoBack()) {
      webViewController.goBack();
      return Future.value(false);
    } else {
      return Future.value(true);
    }
  }

  void handleDownload(
      {required String name,
      required String url,
      required BuildContext context,
      String? base64Str}) async {
    // Get ScaffoldMessenger early before any async operations
    if (!context.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();

    try {
      final streamController = StreamController<String>.broadcast();

      Dio dio = Dio();
      String fileName;
      if (url.toString().lastIndexOf('?') > 0) {
        fileName = url.toString().substring(url.toString().lastIndexOf('/') + 1,
            url.toString().lastIndexOf('?'));
      } else {
        fileName =
            url.toString().substring(url.toString().lastIndexOf('/') + 1);
      }
      String savePath = await getFilePath(base64Str != null ? name : fileName);
      if (context.mounted) {
        final downloadingSnackBarController = scaffoldMessenger.showSnackBar(
          SnackBar(
            duration: Duration(seconds: 30),
            content: StreamBuilder<String>(
              stream: streamController.stream,
              builder: (context, snapshot) {
                return Row(
                  children: [
                    Icon(
                      Icons.download,
                      color: Colors.white,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Text('Number: ${snapshot.data ?? 0}'),
                    SizedBox(
                      width: 10,
                    ),
                    Expanded(
                        child: Text(
                      name,
                      style: TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ))
                  ],
                );
              },
            ),
          ),
        );
        if (base64Str != null) {
          try {
            final base64Data = base64Str.split(',').last;
            final bytes = base64Decode(base64Data);

            final dir = await getApplicationDocumentsDirectory();
            final file = File('${dir.path}/$name');
            await file.writeAsBytes(bytes);
            streamController.add('100%');
            print('✅ File saved to: ${file.path}');
            savePath = file.path;
            Future.delayed(const Duration(seconds: 1), () {
              streamController.close();
              downloadingSnackBarController.close();
            });
          } catch (e) {
            print('❌ Failed to save file: $e');
            streamController.close();
          }
        } else {
          try {
            await dio.download(
              url.toString(),
              savePath,
              onReceiveProgress: (received, total) {
                if (total <= 0) return;
                String pc = (received / total * 100).toStringAsFixed(0);
                if (int.parse(pc) <= 100) {
                  streamController.add('$pc%');
                }
                if (int.parse(pc) == 100) {
                  Future.delayed(const Duration(seconds: 1), () {
                    streamController.close();
                    downloadingSnackBarController.close();
                  });
                }
              },
            );
          } catch (error) {
            streamController.close();
            downloadingSnackBarController.close();
            rethrow;
          }
        }
      }

      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.download,
                  color: Colors.white,
                ),
                SizedBox(
                  width: 10,
                ),
                Icon(
                  Icons.done,
                  color: Colors.green,
                ),
                SizedBox(
                  width: 10,
                ),
                InkWell(
                  onTap: () async {
                    await OpenFile.open(savePath);
                  },
                  child: Text(
                    'Open',
                    style: TextStyle(
                        color: Colors.blue[600],
                        decoration: TextDecoration.underline),
                  ),
                ),
                SizedBox(
                  width: 10,
                ),
                Expanded(
                    child: Text(
                  name,
                  style: TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ))
              ],
            ),
          ),
        );
      }
    } on Exception catch (e) {
      print(e);
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.download,
                color: Colors.white,
              ),
              SizedBox(
                width: 10,
              ),
              Icon(
                Icons.cancel_sharp,
                color: Colors.red,
              ),
              SizedBox(
                width: 10,
              ),
              SizedBox(
                width: 10,
              ),
              Expanded(
                  child: Text(
                name,
                style: TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ))
            ],
          ),
        ));
      }
    }
  }

  void showSnackBarErr(BuildContext context, String content) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error,
                color: Colors.red,
              ),
              SizedBox(
                width: 16,
              ),
              Text(
                content,
                style: TextStyle(color: Colors.black54),
              )
            ],
          ),
          showCloseIcon: true,
          closeIconColor: Colors.black54,
          backgroundColor: Colors.grey[100],
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
              bottom: fullHeight(context) - 150, left: 20, right: 20),
        ),
      );
    }
  }

  Future<String> getFilePath(uniqueFileName) async {
    String path = '';
    String externalStorageDirPath = '';
    if (Platform.isAndroid) {
      try {
        // For Android 10+, use app-specific directory which doesn't require permissions
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Create Downloads folder in app-specific storage
          final downloadDir = Directory('${directory.path}/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          externalStorageDirPath = downloadDir.path;
        } else {
          // Fallback to internal storage
          final internalDir = await getApplicationDocumentsDirectory();
          externalStorageDirPath = internalDir.path;
        }
      } catch (e) {
        print('Error getting storage directory: $e');
        final directory = await getApplicationDocumentsDirectory();
        externalStorageDirPath = directory.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }
    path = '$externalStorageDirPath/$uniqueFileName';
    return path;
  }

  final env = EnvConfig.instance;

  void saveDeviceToken({required String fcmToken, String? uidx}) async {
    final payload = uidx != null
        ? {"token": fcmToken, "userId": uidx}
        : {"token": fcmToken, "userId": null};
    await FcmService().save(payload);
  }

  void deleteDeviceToken({required String fcmToken}) async {
    await FcmService().delete(fcmToken);
  }

  void handleDeepLink(
      {required InAppWebViewController? webViewController,
      required String? path}) async {
    SharedPreferences pref = await SharedPreferences.getInstance();

    if (pref.getString("deepLink") != null) {
      webViewController!.evaluateJavascript(
          source: navigate(pref.getString("deepLink") ?? '/'));
    }

    removeDeepLink();
  }

  void removeDeepLink() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    pref.remove("deepLink");
  }

  Future<void> saveCookies(String url) async {
    try {
      List<Cookie> cookies = await CookieManager.instance().getCookies(
        url: WebUri.uri(Uri.parse(url)),
      );

      List<Map<String, dynamic>> cookiesData = cookies.map((cookie) {
        return {
          "name": cookie.name,
          "value": cookie.value,
          "domain": cookie.domain,
          "path": cookie.path,
          "expiresDate": cookie.expiresDate,
          "isSecure": cookie.isSecure,
          "isHttpOnly": cookie.isHttpOnly,
        };
      }).toList();

      String jsonString = jsonEncode(cookiesData);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('cookies', jsonString);
    } catch (e) {
      print("saving cookie error: $e");
    }
  }

  // if cookies is null while user logged in, then restore cookies
  // resolve issue on iOS (not allow to save cookies)
  Future<void> restoreCookies(String url, CookieManager cookieManager) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('cookies');
    if (Platform.isIOS && jsonString != null) {
      try {
        List<dynamic> cookiesData = jsonDecode(jsonString);

        for (var cookieData in cookiesData) {
          await cookieManager.setCookie(
            url: WebUri.uri(Uri.parse(url)),
            name: cookieData["name"],
            value: cookieData["value"],
            domain: cookieData["domain"],
            path: cookieData["path"],
            expiresDate: cookieData["expiresDate"],
            isSecure: cookieData["isSecure"],
            isHttpOnly: cookieData["isHttpOnly"],
          );
        }
      } catch (e) {
        print("restore cookie error: $e");
      }
    }
  }

  // check user logged in or not via website's cookie
  void getUserId(
      {required CookieManager cookieManager,
      required String url,
      required String name}) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    String? myDeviceToken = pref.getString("fcmToken");
    if (myDeviceToken == null) return;

    Cookie? cookie = await cookieManager.getCookie(
        url: WebUri.uri(Uri.parse(url)), name: name);

    if (pref.get("loginStatus${env.env}") == "logged-in" && cookie == null) {
      deleteDeviceToken(fcmToken: myDeviceToken);
      FlutterAppBadgeControl.isAppBadgeSupported().then((value) {
        FlutterAppBadgeControl.removeBadge();
      });
      pref.setString("loginStatus${env.env}", "logged-out");
      pref.remove('cookies');
      return;
    } else if (cookie != null) {
      String decodedString = Uri.decodeComponent(cookie.value);

      Map<String, dynamic> jsonData = jsonDecode(decodedString);

      UserInfo user = UserInfo.fromJson(jsonData);

      // save fcm token with userId into database
      saveDeviceToken(fcmToken: myDeviceToken, uidx: user.id);
      pref.setString("loginStatus${env.env}", "logged-in");

      //handle saving cookie issue on iOS
      saveCookies(url);
    }
  }

  // handle copy fcm token to clipboard for debugging
  void handleCopy(FToast fToast) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    String? myDeviceToken = pref.getString("fcmToken");
    if (myDeviceToken != null) {
      Clipboard.setData(ClipboardData(text: myDeviceToken));
      fToast.showToast(
        child: WebviewWidgets.toast("Copied FCM Token to clipboard!"),
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 2),
      );
    } else {
      fToast.showToast(
        child: WebviewWidgets.toast("Copied failed!"),
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 2),
      );
    }
  }

  // convert intent url to supertoss scheme
  Uri convertAndAdjustUrl(String url) {
    // Step 1: Check if the URL starts with 'intent:' and handle the scheme
    String? scheme;
    if (url.startsWith('intent:')) {
      // Check if the scheme is embedded in the main URL
      final schemeIndex =
          url.indexOf(':', 7); // Find the first ':' after 'intent:'
      if (schemeIndex != -1 && !url.contains('#Intent;scheme=')) {
        // Scheme is embedded in the main part (e.g., hdcardappcardansimclick)
        scheme = url.substring(7, schemeIndex);
        url = url.replaceFirst('intent:$scheme', 'https');
      } else if (url.contains('#Intent;scheme=')) {
        // Scheme is in the #Intent section
        final intentPart = url.split('#Intent;').last;
        final intentRegex = RegExp(r'scheme=([^;]+);');
        final match = intentRegex.firstMatch(intentPart);
        if (match != null) {
          scheme = Uri.decodeComponent(match.group(1)!);
          url = url.replaceFirst('intent:', 'https:');
        }
      }
    }

    if (scheme == null) {
      throw Exception('Unable to extract scheme from the URL');
    }

    // Parse the modified URL using Uri
    final uri = Uri.parse(url);

    // Extract query parameters from the main part of the URL
    final queryParameters = Map<String, String>.from(uri.queryParameters);

    // Step 2: Extract intent parameters from the #Intent section
    final intentPart = url.split('#Intent;').last;
    final intentParameters = <String, String>{};
    final intentRegex = RegExp(r'([a-zA-Z0-9._-]+)=([^;]+);');
    for (final match in intentRegex.allMatches(intentPart)) {
      intentParameters[match.group(1)!] = Uri.decodeComponent(match.group(2)!);
    }

    // Remove unnecessary parameters like 'scheme' and 'package'
    intentParameters.remove('scheme');
    intentParameters.remove('package');

    // Merge all query parameters
    final allParameters = {...queryParameters, ...intentParameters};

    // Step 3: Construct the final URL with the correct scheme
    final finalUri = Uri(
      scheme: scheme,
      host: uri.host,
      path: uri.path,
      queryParameters: allParameters,
    );

    return finalUri;
  }

  // extract package name from intent url
  String? getIntentPackage(intentUri) {
    // Extract the package using a regex or splitting based on ";"
    final packageMatch = RegExp(r'package=([^;]+)').firstMatch(intentUri);
    final package = packageMatch?.group(1);

    // Print the extracted package
    return package;
  }

  Future<NavigationActionPolicy> navigationActionPolicy(WebUri? uri) async {
    if (uri != null &&
        (uri
                .toString()
                .contains("https://accounts.google.com/o/oauth2/v2/auth") ||
            uri
                .toString()
                .contains("https://kauth.kakao.com/oauth/authorize") ||
            uri
                .toString()
                .contains("https://nid.naver.com/oauth2.0/authorize"))) {
      print("uri => ${uri.uriValue}");
      try {
        final result =
            await launchUrl(uri.uriValue, mode: LaunchMode.externalApplication);
        if (!result) {
          print("Failed to launch Google OAuth URL");
          // You might want to show an error message to the user here
        }
      } catch (e) {
        print("Error launching Google OAuth: $e");
        // You might want to show an error message to the user here
      }
      return NavigationActionPolicy.CANCEL;
    }
    if (uri != null &&
        (uri.scheme == "naversearchthirdlogin" || uri.scheme == "nidlogin")) {
      uri.replace(scheme: 'naversearchthirdlogin');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      return NavigationActionPolicy.CANCEL;
    }
    if (uri.toString().contains("intent:")) {
      try {
        Uri tossUri = Uri.parse(convertAndAdjustUrl(uri.toString()).toString());
        if (await canLaunchUrl(tossUri)) {
          await launchUrl(tossUri,
              mode: LaunchMode.externalNonBrowserApplication);
        } else {
          String? package = getIntentPackage(uri.toString());
          if (package != null &&
              await canLaunchUrl(Uri.parse(
                  "https://play.google.com/store/apps/details?id=$package"))) {
            await launchUrl(
                Uri.parse(
                    "https://play.google.com/store/apps/details?id=$package"),
                mode: LaunchMode.externalNonBrowserApplication);
          }
        }
      } catch (e) {
        return NavigationActionPolicy.CANCEL;
      }
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  bool isNonWebsiteUrl(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.scheme != 'http' && uri.scheme != 'https';
    } catch (e) {
      return true; // Return true for invalid URLs
    }
  }
}
