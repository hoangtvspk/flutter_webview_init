import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:webview_base/config/env_config.dart';
import 'package:webview_base/helpers/Themes.dart';
import 'package:webview_base/helpers/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/src/provider.dart';
import '../provider/navigationBarProvider.dart';
import '../provider/webViewControllerProvider.dart';
import 'HomeScreen.dart';

class MyHomePage extends StatefulWidget {
  final String webUrl;
  final bool showDevToolButton;
  final int? windowId;

  const MyHomePage(
      {super.key,
      required this.webUrl,
      this.windowId,
      this.showDevToolButton = false});
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

  StreamSubscription<Uri>? _linkSubscription;

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

    Future.delayed(Duration.zero, () {
      if (context.mounted) {
        context
            .read<NavigationBarProvider>()
            .setAnimationController(navigationContainerAnimationController);
      }
    });
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
    final provider =
        Provider.of<WebViewControllerProvider>(context, listen: false);
    InAppWebViewController? webViewController = provider.controller;

    if (webViewController != null && url != null) {
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
          child: SafeArea(
            top: Platform.isIOS ? true : true,
            bottom: Platform.isIOS ? false : false,
            child: Scaffold(
              extendBody: true,
              body: Navigator(
                key: _navigatorKeys[0],
                onGenerateRoute: (routeSettings) {
                  return MaterialPageRoute(
                      builder: (_) => HomeScreen(
                            widget.webUrl,
                            windowId: widget.windowId,
                            showDevToolButton: widget.showDevToolButton,
                          ));
                },
              ),
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

    final provider =
        Provider.of<WebViewControllerProvider>(context, listen: false);
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
                          color: Color(0xff5A4FF3),
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
