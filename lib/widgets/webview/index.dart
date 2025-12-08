import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
// ignore: implementation_imports
import 'package:provider/src/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_base/config/env_config.dart';
import 'package:webview_base/provider/webViewControllerProvider.dart';
import 'package:webview_base/provider/webviewURLProvider.dart';
import 'package:webview_base/widgets/webview/not_found.dart';
import 'package:webview_base/widgets/webview/webview_window.dart';

import '../../constants/javascript.dart';
import '../../helpers/Colors.dart';
import '../../models/web_post_message.dart';
import '../../provider/navigationBarProvider.dart';
import '../../provider/webviewLoadingProvider.dart';
import '../../utils/permission.dart';
import '../../utils/webview.dart';
import 'loading_overlay.dart';
import 'no_internet_widget.dart';

class WebViewContainer extends StatefulWidget {
  final String url;
  final bool webUrl;
  final int? windowId;
  final bool showDevToolButton;

  const WebViewContainer(
      {required this.url,
      required this.webUrl,
      this.windowId,
      this.showDevToolButton = false,
      super.key});

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer>
    with SingleTickerProviderStateMixin {
  double progress = 0;
  double windowprogress = 0;
  int _previousScrollY = 0;

  String inititalDeeplink = '';
  String url = '';
  String downdloadPercent = '0';

  bool isLoading = false;
  bool isNewWindowLoading = false;
  bool showErrorPage = false;
  bool slowInternetPage = false;
  bool noInternet = false;
  bool showNoInternet = false;
  bool isOpenDialog = false;
  bool _validURL = false;
  bool canGoBack = false;

  late AnimationController animationController;
  late Animation<double> animation;
  late FToast fToast;
  late PullToRefreshController _pullToRefreshController;

  final bool _allowClosePopUp = true;
  final expiresDate =
      DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey webViewKey = GlobalKey();
  final WebviewUtils webviewUtils = WebviewUtils();
  final env = EnvConfig.instance;

  PackageInfo? packageInfo;
  WebviewWindow webviewWindow = WebviewWindow();
  CookieManager cookieManager = CookieManager.instance();
  InAppWebViewController? webViewController;
  BuildContext? dialogContext;
  final keepAlive = InAppWebViewKeepAlive();

  InAppWebViewSettings options = InAppWebViewSettings(
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
      useOnDownloadStart: true,
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: true,
      cacheEnabled: false,
      isInspectable: true,
      clearCache: false,
      supportZoom: true,
      preferredContentMode: UserPreferredContentMode.MOBILE,
      // userAgent: "random",
      verticalScrollBarEnabled: false,
      horizontalScrollBarEnabled: false,
      transparentBackground: true,
      allowFileAccessFromFileURLs: true,
      allowUniversalAccessFromFileURLs: true,
      thirdPartyCookiesEnabled: true,
      allowFileAccess: true,
      supportMultipleWindows: Platform.isIOS,
      allowsInlineMediaPlayback: true);

  @override
  void initState() {
    super.initState();

    invalidUrl();
    initFToast();
    getPackageInfo();
    initPullToRequest();
    initAnimation();
  }

  @override
  void dispose() {
    animationController.dispose();
    webViewController = null;
    super.dispose();
  }

  void invalidUrl() {
    _validURL = Uri.tryParse(widget.url)?.isAbsolute ?? false;
  }

  void initFToast() {
    fToast = FToast();
    fToast.init(context);
  }

  void getPackageInfo() async {
    PackageInfo getPackageInfo = await PackageInfo.fromPlatform();
    SharedPreferences pref = await SharedPreferences.getInstance();
    setState(() {
      packageInfo = getPackageInfo;
      inititalDeeplink = pref.getString("deepLink") ?? '';
    });
  }

  void initPullToRequest() {
    try {
      _pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(color: primaryColor),
        onRefresh: () async {
          if (Platform.isAndroid) {
            webViewController!.reload();
          } else if (Platform.isIOS) {
            webViewController!.loadUrl(
                urlRequest: URLRequest(url: await webViewController!.getUrl()));
          }
        },
      );
    } on Exception catch (e) {
      print(e);
    }
  }

  void initAnimation() {
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    animation = Tween(begin: 0.0, end: 1.0).animate(animationController)
      ..addListener(() {});
  }

  void setController({required InAppWebViewController controller}) {
    Provider.of<WebViewControllerProvider>(context, listen: false)
        .setController(controller);
  }

  void defineRouteChangeFunction() {
    webViewController?.addJavaScriptHandler(
        handlerName: "onRouteChanged",
        callback: (args) {
          String currentUrl = args[0];
          print("SPA navigated to: $currentUrl");
          webviewUtils.getUserId(
              cookieManager: cookieManager,
              url: widget.url,
              name: "USER_INFOR");
          context.read<WebviewURLProvider>().setCurrentURL(currentUrl);
          if (isOpenDialog == true && dialogContext != null) {
            Navigator.of(dialogContext!).pop();
          }
        });
  }

  void setupCookie() async {
    await cookieManager.setCookie(
      url: WebUri.uri(Uri.parse(widget.url)),
      name: "webview",
      value: '{"platform": "${Platform.isIOS ? "iOS" : "android"}"}',
      expiresDate: expiresDate,
      isHttpOnly: false,
      isSecure: false,
    );
  }

  void handlePostMessage({required InAppWebViewController controller}) async {
    print("SHARING");
    if (defaultTargetPlatform != TargetPlatform.android ||
        await WebViewFeature.isFeatureSupported(
            WebViewFeature.WEB_MESSAGE_LISTENER)) {
      await controller.addWebMessageListener(WebMessageListener(
        jsObjectName: "webviewListener",
        onPostMessage: (message, sourceOrigin, isMainFrame, replyProxy) {
          print("message: $message");
          if (message != null && message.data != null) {
            dynamic postedMessage =
                WebPostMessage.fromJson(jsonDecode(message.data.toString()));
            print('message: ${postedMessage.type}');
            if (postedMessage.type == 'share') {
              Share.share(postedMessage.messageData?.url ?? '',
                  subject: postedMessage.messageData?.title ?? '');
            } else if (postedMessage.type == 'contacts') {
              getContacts(controller: controller);
            } else if (postedMessage.type == 'download-template-base64') {
              webviewUtils.handleDownload(
                  name: postedMessage.messageData?.url ?? '',
                  url: postedMessage.messageData?.title ?? '',
                  context: context,
                  base64Str: postedMessage.messageData?.title ?? '');
            }
          }
        },
      ));
    }
  }

  void getContacts({required InAppWebViewController controller}) async {
    try {
      print('Requesting contacts permission...');
      final statusBefore = await Permission.contacts.status;
      print('Status before: $statusBefore');

      final permissionStatus = await Permission.contacts.request();
      print('Permission status: $permissionStatus');

      if (permissionStatus == PermissionStatus.permanentlyDenied) {
        controller!
            .evaluateJavascript(source: handleException("Access denied"));
        print('contacts permission denied');
        if (statusBefore == PermissionStatus.denied) {
        } else {
          openAppSettings();
        }
      } else if (permissionStatus == PermissionStatus.granted) {
        print('Permission granted, fetching contacts...');
        final contacts =
            await FlutterContacts.getContacts(withProperties: true);
        print('Contacts found: ${contacts.length}');

        // Convert contacts to JSON format
        List<Map<String, dynamic>> contactsJson = [];
        for (var contact in contacts) {
          // Get all phone numbers for this contact
          var phones = contact.phones;

          if (phones.isEmpty) {
            // If contact has no phone numbers, add it as is
            contactsJson.add({
              'name': contact.displayName,
              'tel': '',
              'id': contact.id,
            });
          } else {
            // For each phone number, create a separate entry
            for (var phone in phones) {
              contactsJson.add({
                'name': contact.displayName,
                'tel': phone.number,
                'id': '${contact.id} ${phone.number}',
              });
            }
          }
        }

        print('Final JSON to send: $contactsJson');
        // Convert to JSON string and send to webview
        String jsonString = jsonEncode(contactsJson);
        // Escape the JSON string for JavaScript
        jsonString = jsonString.replaceAll("'", "\\'");
        controller!.evaluateJavascript(source: setContacts(jsonString));
      } else if (statusBefore == PermissionStatus.denied &&
          Platform.isAndroid) {
        controller!
            .evaluateJavascript(source: handleException("Access denied"));
        print('contacts permission denied');
      }
    } catch (e) {
      print('Error in getContacts: $e');
      print('Error stack trace: ${StackTrace.current}');
    }
  }

  void onScrollChanged({required int y}) {
    try {
      int currentScrollY = y;
      if (currentScrollY > _previousScrollY) {
        _previousScrollY = currentScrollY;
        if (!context
            .read<NavigationBarProvider>()
            .animationController
            .isAnimating) {
          context.read<NavigationBarProvider>().animationController.forward();
        }
      } else {
        _previousScrollY = currentScrollY;

        if (!context
            .read<NavigationBarProvider>()
            .animationController
            .isAnimating) {
          context.read<NavigationBarProvider>().animationController.reverse();
        }
      }
    } catch (e) {
      print(e);
    }
  }

  void onWebViewCreated({required InAppWebViewController controller}) {
    webViewController = controller;

    setController(controller: controller);

    webviewUtils.restoreCookies(widget.url, cookieManager);

    defineRouteChangeFunction();

    setupCookie();

    handlePostMessage(controller: controller);
  }

  void onLoadStart(
      {required InAppWebViewController controller, required WebUri? url}) {
    print('----------GET URL: $url');

    setState(() {
      noInternet = false;
      isLoading = true;
      showErrorPage = false;
      slowInternetPage = false;
      this.url = url.toString();
    });
    if (isOpenDialog == true && dialogContext != null) {
      Navigator.of(dialogContext!).pop();
    }
    context.read<WebviewURLProvider>().setCurrentURL(url.toString());
  }

  void onLoadStop(
      {required InAppWebViewController controller,
      required WebUri? url}) async {
    if (webViewController != null) {
      Uri? uri = url?.uriValue;
      if (uri != null) {
        webviewUtils.handleDeepLink(
            webViewController: webViewController,
            path: uri.path + (uri.hasQuery ? '?${uri.query}' : ''));
      }
    }
    // print("${webViewController.}")
    webviewUtils.getUserId(
        cookieManager: cookieManager, url: widget.url, name: "USER_INFOR");
    await controller.evaluateJavascript(source: listenRouterChange);
    _pullToRefreshController.endRefreshing();
    print("stop successful");
    setState(() {
      this.url = url.toString();
      isLoading = false;
      if (!noInternet && showNoInternet) {
        showNoInternet = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        body: Column(
          children: [
            Expanded(
              child: Padding(
                  padding:
                      EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  child: GestureDetector(
                    onHorizontalDragEnd: (dragEndDetails) async {
                      if (dragEndDetails.primaryVelocity! > 0) {
                        if (await webViewController!.canGoBack()) {
                          print("back to : ${webViewController!.getUrl()}");
                          webViewController!.goBack();
                        }
                      }
                    },
                    // ignore: deprecated_member_use
                    child: !widget.webUrl
                        ? SizedBox()
                        : Stack(
                            alignment: AlignmentDirectional.topStart,
                            clipBehavior: Clip.hardEdge,
                            children: [
                              _validURL
                                  ? InAppWebView(
                                      initialUrlRequest: URLRequest(
                                          url: WebUri.uri(
                                              Uri.parse(widget.url))),
                                      initialSettings: options,
                                      windowId: widget.windowId,
                                      keepAlive: keepAlive,
                                      pullToRefreshController:
                                          _pullToRefreshController,
                                      gestureRecognizers: <Factory<
                                          OneSequenceGestureRecognizer>>{
                                        Factory<OneSequenceGestureRecognizer>(
                                            () => EagerGestureRecognizer()),
                                      },
                                      onWebViewCreated: (controller) async {
                                        onWebViewCreated(
                                            controller: controller);
                                      },
                                      onScrollChanged:
                                          (controller, x, y) async {
                                        onScrollChanged(y: y);
                                      },
                                      onLoadStart: (controller, url) async {
                                        // Only reset loading state on initial load
                                        // After initial load completes, don't reset to avoid showing splash again
                                        final loadingProvider =
                                            Provider.of<WebViewLoadingProvider>(
                                                context,
                                                listen: false);
                                        // Only reset if progress hasn't reached 1.0 yet (initial load not completed)
                                        if (loadingProvider.progress < 1.0) {
                                          loadingProvider.reset();
                                        }
                                        onLoadStart(
                                            controller: controller, url: url);
                                      },
                                      onLoadStop: (controller, url) async {
                                        onLoadStop(
                                            controller: controller, url: url);
                                      },
                                      onReceivedError: (
                                        controller,
                                        url,
                                        webResourceError,
                                      ) async {
                                        _pullToRefreshController
                                            .endRefreshing();
                                        print(
                                            "onReceivedError ${webResourceError.description}");

                                        void handleNonWebsiteUrl(
                                            Uri uri) async {
                                          if (await canLaunchUrl(uri)) {
                                            print("launch unsupport url $uri");
                                            await launchUrl(uri);
                                          } else {
                                            webViewController?.stopLoading();
                                            webviewUtils.showSnackBarErr(
                                                context, "앱이 설치되어 있지 않습니다.");
                                          }
                                        }

                                        setState(() {
                                          isLoading = false;
                                          progress = 1;
                                          final uri = url.url;
                                          if (webResourceError.description ==
                                              "The operation couldn't be completed. (NSURLErrorDomain error -999.)") {
                                            webViewController?.loadUrl(
                                                urlRequest: URLRequest(
                                                    url: WebUri.uri(Uri.parse(
                                                        widget.url))));
                                            return;
                                          }
                                          if (Platform.isIOS &&
                                              webResourceError.description ==
                                                  'unsupported URL' &&
                                              webviewUtils.isNonWebsiteUrl(
                                                  uri.toString())) {
                                            handleNonWebsiteUrl(uri);
                                            return;
                                          }
                                          if (Platform.isAndroid) {
                                            if (webResourceError.description ==
                                                'net::ERR_UNKNOWN_URL_SCHEME') {
                                              webViewController?.goBack();
                                              return;
                                            }

                                            if (webResourceError.description ==
                                                    'net::ERR_INTERNET_DISCONNECTED' ||
                                                webResourceError.description ==
                                                    'net::ERR_TIMED_OUT') {
                                              showNoInternet = true;
                                              noInternet = true;
                                              return;
                                            }
                                          }

                                          if (Platform.isIOS &&
                                              webResourceError.description ==
                                                  'The Internet connection appears to be offline.') {
                                            showNoInternet = true;
                                            noInternet = true;
                                            return;
                                          }
                                        });
                                      },
                                      onReceivedHttpError:
                                          (controller, url, statusCode) {
                                        _pullToRefreshController
                                            .endRefreshing();
                                        print(
                                            "onReceivedHttpError $statusCode");
                                        // setState(() {
                                        //   showErrorPage = true;
                                        //   isLoading = false;
                                        // });
                                      },
                                      onReceivedServerTrustAuthRequest:
                                          (controller, challenge) async {
                                        return ServerTrustAuthResponse(
                                            action:
                                                ServerTrustAuthResponseAction
                                                    .PROCEED);
                                      },
                                      onGeolocationPermissionsShowPrompt:
                                          (controller, origin) async {
                                        await Permission.location.request();
                                        return Future.value(
                                            GeolocationPermissionShowPromptResponse(
                                                origin: origin,
                                                allow: true,
                                                retain: true));
                                      },
                                      onPermissionRequest:
                                          (controller, request) async {
                                        return PermissionResponse(
                                            resources: request.resources,
                                            action:
                                                PermissionResponseAction.GRANT);
                                      },
                                      onProgressChanged:
                                          (controller, progress) {
                                        if (progress == 100) {
                                          _pullToRefreshController
                                              .endRefreshing();
                                          isLoading = false;
                                        }
                                        setState(() {
                                          this.progress = progress / 100;
                                        });
                                        // Notify loading provider
                                        // The provider will handle preventing progress from going below 1.0
                                        // after initial load completes
                                        Provider.of<WebViewLoadingProvider>(
                                                context,
                                                listen: false)
                                            .setProgress(progress / 100);

                                        // Trigger splash visibility update in MainScreen
                                        // This will be handled by Consumer's addPostFrameCallback
                                      },
                                      shouldOverrideUrlLoading:
                                          (controller, navigationAction) async {
                                        final uri =
                                            navigationAction.request.url;

                                        return webviewUtils
                                            .navigationActionPolicy(uri);
                                      },
                                      onCreateWindow: (controller,
                                          createWindowRequest) async {
                                        final webUri =
                                            createWindowRequest.request.url;
                                        if (webUri.toString().contains(RegExp(
                                            r'\.(pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|txt|csv)$'))) {
                                          print("downloading file");
                                          // Prevent the webview from loading the URL
                                          return false;
                                        }
                                        if (webUri != null &&
                                            (webUri.toString().contains(
                                                    "https://accounts.google.com/o/oauth2/v2/auth") ||
                                                webUri.toString().contains(
                                                    "https://kauth.kakao.com/oauth/authorize") ||
                                                webUri.toString().contains(
                                                    "https://nid.naver.com/oauth2.0/authorize"))) {
                                          return false;
                                        }
                                        if (Platform.isAndroid) {
                                          return false;
                                        }

                                        print('onCreateWindow $webUri');
                                        webviewWindow.createWindow(
                                            windowId:
                                                createWindowRequest.windowId,
                                            setState: setState,
                                            isOpenDialog: isOpenDialog,
                                            isNewWindowLoading:
                                                isNewWindowLoading,
                                            allowClosePopUp: _allowClosePopUp,
                                            context: context,
                                            dialogContext: dialogContext,
                                            url: url,
                                            options: options,
                                            webinitialUrl: 'webinitialUrl');
                                        return true;
                                      },
                                      onDownloadStartRequest: (controller,
                                          downloadStartRrquest) async {
                                        setState(() {
                                          isLoading = false;
                                          progress = 1;
                                        });
                                        enableStoragePermision()
                                            .then((status) async {
                                          String url = downloadStartRrquest.url
                                              .toString();
                                          String fileName = downloadStartRrquest
                                              .suggestedFilename
                                              .toString();
                                          if (status == true) {
                                            webviewUtils.handleDownload(
                                                url: url,
                                                context: context,
                                                name: fileName);
                                          } else {
                                            openAppSettings();
                                          }
                                        });
                                      },
                                      onUpdateVisitedHistory: (controller, url,
                                          androidIsReload) async {
                                        setState(() {
                                          this.url = url.toString();
                                        });
                                      },
                                      onConsoleMessage: (controller, message) {
                                        print(
                                            '------console-log: ${message.message}');
                                      },
                                    )
                                  : Center(
                                      child: Text(
                                      'Url is not valid',
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    )),
                              showNoInternet
                                  ? Center(
                                      child: NoInternetWidget(reload: () async {
                                        if (Platform.isAndroid) {
                                          webViewController!.reload();
                                        } else if (Platform.isIOS) {
                                          webViewController!.loadUrl(
                                              urlRequest: URLRequest(
                                                  url: WebUri.uri(
                                                      Uri.parse(url))));
                                        }
                                      }),
                                    )
                                  : const SizedBox(height: 0, width: 0),
                              showErrorPage
                                  ? Center(
                                      child: NotFound(
                                          webViewController: webViewController!,
                                          url: url,
                                          title1: 'Page not found',
                                          title2:
                                              'Page not found, please try again'))
                                  : const SizedBox(height: 0, width: 0),
                              slowInternetPage
                                  ? Center(
                                      child: NotFound(
                                          webViewController: webViewController!,
                                          url: url,
                                          title1: 'Incorrect URL',
                                          title2:
                                              'Incorrect URL, please try again'))
                                  : const SizedBox(height: 0, width: 0),
                              // Loading overlay circle
                              progress < 1.0 && _validURL
                                  ? LoadingOverlay(
                                      progress: progress,
                                      animation: animation,
                                    )
                                  : const SizedBox.shrink(),
                            ],
                          ),
                  )),
            )
          ],
        ));
  }
}
