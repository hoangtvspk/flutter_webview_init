import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:webview_base/config/env_config.dart';
import 'package:webview_base/helpers/Themes.dart';
import 'package:webview_base/helpers/icons.dart';
import 'package:webview_base/provider/webview_provider.dart';
import 'package:webview_base/repositories/auth_repository.dart';
import 'package:webview_base/widgets/common/dialog.dart';
import 'package:webview_base/widgets/splash_overlay/index.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:version/version.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:webview_base/widgets/webview/index.dart';
import '../provider/navigation_bar_provider.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
  });
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late AnimationController idleAnimation;
  late AnimationController onSelectedAnimation;
  late AnimationController onChangedAnimation;
  Duration animationDuration = const Duration(milliseconds: 700);
  late AnimationController navigationContainerAnimationController =
      AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [];
  final AppDialog appDialog = AppDialog();

  StreamSubscription<Uri>? _linkSubscription;

  // Track app initialization state locally
  bool _isAppInitialized = false;
  bool _isUpdateRequired = false;
  bool _shouldHideSplash = false;
  Timer? _splashHideTimer;

  @override
  void initState() {
    super.initState();
    initializeTabs();
    idleAnimation = AnimationController(vsync: this);
    onSelectedAnimation =
        AnimationController(vsync: this, duration: animationDuration);
    onChangedAnimation =
        AnimationController(vsync: this, duration: animationDuration);

    initDeepLinks();

    // Reset loading provider after build phase completes
    // This ensures splash shows on initial load and hot reload
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final loadingProvider =
            Provider.of<WebViewProvider>(context, listen: false);
        // Only reset if not already initialized (for hot reload case)
        // If already initialized and webview loaded, keep it hidden
        if (!_isAppInitialized || loadingProvider.progress < 1.0) {
          loadingProvider.resetLoading();
        }
      }
    });

    _initializeApp();

    Future.delayed(Duration.zero, () {
      // ignore: use_build_context_synchronously
      context
          .read<NavigationBarProvider>()
          .setAnimationController(navigationContainerAnimationController);
    });
  }

  // Initialize app logic (moved from SplashScreen)
  Future<void> _initializeApp() async {
    try {
      _isUpdateRequired = await _checkUpdateRequired();
      if (_isUpdateRequired && mounted) {
        appDialog.showUpdateDialog(context);
        return;
      }
      await FirebaseMessaging.instance.getAPNSToken();
      var fcmToken = await FirebaseMessaging.instance.getToken();

      AuthRepository().setFcmToken(fcmToken: fcmToken ?? '');
      print('--------fcmToken:$fcmToken');
    } on Exception catch (e) {
      print("get fcm err : =>>> $e");
    } finally {
      // Mark app initialization as complete
      print("isUpdateRequired => $_isUpdateRequired");
      setState(() {
        _isAppInitialized = true;
      });

      // Update loading state based on initialization and webview progress
      // _updateSplashVisibility();
    }
  }

  // Check update required when the version from Firebase Remote Config is greater than the current version
  Future<bool> _checkUpdateRequired() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      Version.parse(currentVersion); // Parse để validate version format
      return false;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<void> initDeepLinks() async {
    // Handle links
    AppLinks().getInitialLink().then((link) {
      print("link => $link");
      if (link != null) {
        openAppLink(link);
      }
    });
    _linkSubscription = AppLinks().uriLinkStream.listen((uri) {
      debugPrint('onAppLink: $uri');
      openAppLink(uri);
    });
  }

  void openAppLink(Uri uri) {
    String? url = uri.toString().replaceFirst("ezsale://app?url=", "");
    final provider = Provider.of<WebViewProvider>(context, listen: false);
    InAppWebViewController? webViewController = provider.controller;

    if (webViewController != null && url.isNotEmpty) {
      webViewController.loadUrl(
          urlRequest: URLRequest(url: WebUri.uri(Uri.parse(url))));
    }
  }

  initializeTabs() {
    _navigatorKeys.add(GlobalKey<NavigatorState>());
  }

  @override
  void dispose() {
    idleAnimation.dispose();
    onSelectedAnimation.dispose();
    onChangedAnimation.dispose();
    navigationContainerAnimationController.dispose();
    _linkSubscription?.cancel();
    _splashHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Theme.of(context).cardColor,
      statusBarBrightness: Theme.of(context).brightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
      statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ));
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () => _navigateBack(context),
      child: GestureDetector(
        onTap: () =>
            context.read<NavigationBarProvider>().animationController.reverse(),
        child: Container(
          color: Colors.white,
          child: Scaffold(
            extendBody: true,
            body: Consumer<WebViewProvider>(
              builder: (context, loadingProvider, child) {
                // Update splash visibility when progress changes
                bool isLoaded = _isAppInitialized &&
                    loadingProvider.progress >= 1.0 &&
                    !_isUpdateRequired;

                // Handle delay before hiding splash
                if (isLoaded && !_shouldHideSplash) {
                  _splashHideTimer?.cancel();
                  _splashHideTimer =
                      Timer(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      setState(() {
                        _shouldHideSplash = true;
                      });
                    }
                  });
                } else if (!isLoaded && _shouldHideSplash) {
                  // Reset flag when loading again
                  _splashHideTimer?.cancel();
                  _shouldHideSplash = false;
                }

                return SafeArea(
                  top: isLoaded && _shouldHideSplash,
                  bottom: false,
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: isLoaded ? 1.0 : 0.0,
                        child: Navigator(
                          key: _navigatorKeys[0],
                          onGenerateRoute: (routeSettings) {
                            return MaterialPageRoute(
                                builder: (_) => WebViewContainer());
                          },
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: (!isLoaded || !_shouldHideSplash) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: (!isLoaded || !_shouldHideSplash)
                            ? SplashOverlay()
                            : SizedBox.shrink(),
                      ),
                      // Splash screen overlay that hides when webview loads
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _navigateBack(BuildContext context) async {
    if (Platform.isIOS && Navigator.of(context).userGestureInProgress) {
      return Future.value(true);
    }
    final env = EnvConfig.instance;

    final provider = Provider.of<WebViewProvider>(context, listen: false);
    InAppWebViewController? webViewController = provider.controller;

    if (webViewController == null) {
      return Future.value(true);
    }

    if (await webViewController.canGoBack()) {
      // Check if the URL has specific query parameters
      try {
        WebUri? currentUrl = await webViewController.getUrl();
        if (currentUrl == null) {
          return Future.value(true);
        }
        Map<String, String> params = currentUrl.queryParameters;
        if (params['token_version_id'] != null &&
            params['enc_data'] != null &&
            params['integrity_value'] != null) {
          await webViewController.loadUrl(
              urlRequest:
                  URLRequest(url: WebUri.uri(Uri.parse(env.webviewUrl))));
        } else {
          await webViewController.goBack();
        }
        return Future.value(false);
      } catch (e) {
        print("Error handling navigation: $e");
        await webViewController.goBack();
        return Future.value(false);
      }
    } else {
      showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (context) => AlertDialog(
                insetPadding: EdgeInsets.all(24), // Remove default padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ), // Optional: Add rounded corners
                title: Container(
                    margin: EdgeInsets.symmetric(horizontal: 24),
                    width: fullWidth(context) - 48,
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          Theme.of(context).colorScheme.exitIcon,
                          width: perWidth(context, 80),
                          colorFilter: ColorFilter.mode(
                              Color(0xff5A4FF3), BlendMode.srcIn),
                        ),
                        SizedBox(
                          height: 24,
                        ),
                        Text(
                          '앱을 종료 하시겠습니까?',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    )),
                actions: <Widget>[
                  SizedBox(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Color(0xffC9CCCF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    4), // Set your desired radius
                              ),
                              minimumSize: Size(100, 40),
                            ),
                            child: const Text(
                              '아니요',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xff1F1F1F),
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              SystemNavigator.pop();
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Color(0xff5A4FF3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    4), // Set your desired radius
                              ),
                              minimumSize: Size(100, 40),
                            ),
                            child: const Text(
                              '네',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ));

      return Future.value(true);
    }
  }
}
