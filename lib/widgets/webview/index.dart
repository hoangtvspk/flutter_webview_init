import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:webview_base/config/env_config.dart';
import 'package:webview_base/config/webview_config.dart';
import 'package:webview_base/helpers/Colors.dart';
import 'package:webview_base/mixins/webview_download_mixin.dart';
import 'package:webview_base/mixins/webview_lifecycle_mixin.dart';
import 'package:webview_base/mixins/webview_navigation_mixin.dart';
import 'package:webview_base/provider/webview_provider.dart';
import 'package:webview_base/widgets/webview/dev_tool_button.dart';
import 'package:webview_base/widgets/webview/not_found.dart';
import 'package:webview_base/widgets/webview/webview_window.dart';

import 'loading_overlay.dart';
import 'no_internet_widget.dart';

class WebViewContainer extends StatefulWidget {
  const WebViewContainer({super.key});

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer>
    with
        SingleTickerProviderStateMixin,
        WebViewLifecycleMixin,
        WebViewDownloadMixin,
        WebViewNavigationMixin {
  // Progress States
  double _progress = 0;
  String _currentUrl = '';

  // Error States
  bool _showErrorPage = false;
  bool _slowInternetPage = false;
  bool _noInternet = false;
  bool _showNoInternet = false;
  bool _isValidURL = false;

  // Dialog States
  bool _isDialogLoading = false;
  bool _isOpenDialog = false;
  bool _allowClosePopUp = true;

  late PullToRefreshController _pullToRefreshController;

  final String _initialUrl = EnvConfig.instance.webviewUrl;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final WebviewWindow _webviewWindow = WebviewWindow();
  final _keepAlive = InAppWebViewKeepAlive();
  final InAppWebViewSettings _options = WebViewConfig.getDefaultSettings();

  InAppWebViewController? _webViewController;
  BuildContext? _dialogContext;

  @override
  void initState() {
    super.initState();

    _isValidURL = validateUrl(_initialUrl);
    _initPullToRequest();
  }

  void _initPullToRequest() {
    try {
      _pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(color: primaryColor),
        onRefresh: () async {
          if (Platform.isAndroid) {
            _webViewController!.reload();
          } else if (Platform.isIOS) {
            _webViewController!.loadUrl(
                urlRequest:
                    URLRequest(url: await _webViewController!.getUrl()));
          }
        },
      );
    } on Exception catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
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
                        if (await _webViewController?.canGoBack() ?? false) {
                          print(
                              "back to : ${await _webViewController?.getUrl()}");
                          _webViewController?.goBack();
                        }
                      }
                    },
                    // ignore: deprecated_member_use
                    child: Stack(
                      alignment: AlignmentDirectional.topStart,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        _isValidURL
                            ? InAppWebView(
                                initialUrlRequest: URLRequest(
                                    url: WebUri.uri(Uri.parse(_initialUrl))),
                                initialSettings: _options,
                                keepAlive: _keepAlive,
                                pullToRefreshController:
                                    _pullToRefreshController,
                                gestureRecognizers: <Factory<
                                    OneSequenceGestureRecognizer>>{
                                  Factory<OneSequenceGestureRecognizer>(
                                      () => EagerGestureRecognizer()),
                                },
                                onWebViewCreated: (controller) async {
                                  // Delegate to mixin for business logic
                                  _webViewController = controller;
                                  await onWebViewCreated(
                                    controller: controller,
                                    onDownload: handleDownload,
                                    onControllerInitialized: (c) {},
                                  );
                                },
                                onScrollChanged: (controller, x, y) async {
                                  // Use mixin method with state tracking
                                  super.onScrollChanged(y: y);
                                },
                                onLoadStart: (controller, url) async {
                                  // Delegate to mixin
                                  super.onLoadStart(
                                    controller: controller,
                                    url: url,
                                    isOpenDialog: _isOpenDialog,
                                    dialogContext: _dialogContext,
                                    onUpdate: () {
                                      setState(() {
                                        _noInternet = false;
                                        _showErrorPage = false;
                                        _slowInternetPage = false;
                                        _currentUrl = url.toString();
                                      });
                                    },
                                  );
                                },
                                onLoadStop: (controller, url) async {
                                  // Delegate to mixin
                                  await super.onLoadStop(
                                    controller: controller,
                                    url: url,
                                    webViewController: _webViewController,
                                    pullToRefreshController:
                                        _pullToRefreshController,
                                    onUpdate: () {
                                      setState(() {
                                        _currentUrl = url.toString();
                                        if (!_noInternet && _showNoInternet) {
                                          _showNoInternet = false;
                                        }
                                      });
                                    },
                                  );
                                },
                                onReceivedError: (
                                  controller,
                                  request,
                                  error,
                                ) async {
                                  await onReceivedError(
                                    controller: controller,
                                    request: request,
                                    error: error,
                                    pullToRefreshController:
                                        _pullToRefreshController,
                                    webViewController: _webViewController,
                                    onShowError: showSnackBarErr,
                                    onUpdateState: ({
                                      progress,
                                      showNoInternet,
                                      noInternet,
                                    }) {
                                      setState(() {
                                        if (progress != null) {
                                          _progress = progress;
                                        }
                                        if (showNoInternet != null) {
                                          _showNoInternet = showNoInternet;
                                        }
                                        if (noInternet != null) {
                                          _noInternet = noInternet;
                                        }
                                      });
                                    },
                                  );
                                },
                                onReceivedHttpError:
                                    (controller, url, statusCode) {
                                  _pullToRefreshController.endRefreshing();
                                  print("onReceivedHttpError $statusCode");
                                  // setState(() {
                                  //   showErrorPage = true;
                                  //   isLoading = false;
                                  // });
                                },
                                onReceivedServerTrustAuthRequest:
                                    (controller, challenge) async {
                                  return ServerTrustAuthResponse(
                                      action: ServerTrustAuthResponseAction
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
                                      action: PermissionResponseAction.GRANT);
                                },
                                onProgressChanged: (controller, progress) {
                                  if (progress == 100) {
                                    _pullToRefreshController.endRefreshing();
                                  }
                                  setState(() {
                                    _progress = progress / 100;
                                  });
                                  // Notify loading provider
                                  // The provider will handle preventing progress from going below 1.0
                                  // after initial load completes
                                  Provider.of<WebViewProvider>(context,
                                          listen: false)
                                      .setProgress(progress / 100);

                                  // Trigger splash visibility update in MainScreen
                                  // This will be handled by Consumer's addPostFrameCallback
                                },
                                shouldOverrideUrlLoading:
                                    (controller, navigationAction) async {
                                  return super.getNavigationPolicy(
                                      navigationAction.request.url);
                                },
                                onCreateWindow:
                                    (controller, createWindowRequest) async {
                                  return handleCreateWindow(
                                    createWindowRequest: createWindowRequest,
                                    webviewWindow: _webviewWindow,
                                    isOpenDialog: _isOpenDialog,
                                    isNewWindowLoading: _isDialogLoading,
                                    allowClosePopUp: _allowClosePopUp,
                                    dialogContext: _dialogContext,
                                    url: _currentUrl,
                                    options: _options,
                                    setIsOpenDialog: (value) =>
                                        setState(() => _isOpenDialog = value),
                                    setIsNewWindowLoading: (value) => setState(
                                        () => _isDialogLoading = value),
                                    setAllowClosePopUp: (value) => setState(
                                        () => _allowClosePopUp = value),
                                  );
                                },
                                onDownloadStartRequest:
                                    (controller, downloadStartRequest) async {
                                  await onDownloadStartRequest(
                                    request: downloadStartRequest,
                                    onUpdateState: ({isLoading, progress}) {
                                      setState(() {
                                        if (progress != null) {
                                          _progress = progress;
                                        }
                                      });
                                    },
                                  );
                                },
                                onUpdateVisitedHistory:
                                    (controller, url, androidIsReload) async {
                                  onUpdateVisitedHistory(
                                      url: url,
                                      onUpdateUrl: (newUrl) {
                                        setState(() {
                                          _currentUrl = newUrl;
                                        });
                                      });
                                },
                                onConsoleMessage: (controller, message) {
                                  super.onConsoleMessage(message);
                                },
                              )
                            : Center(
                                child: Text(
                                'Url is not valid',
                                style: Theme.of(context).textTheme.bodyLarge,
                              )),
                        _showNoInternet
                            ? Center(
                                child: NoInternetWidget(reload: () async {
                                  if (Platform.isAndroid) {
                                    _webViewController?.reload();
                                  } else if (Platform.isIOS) {
                                    _webViewController?.loadUrl(
                                        urlRequest: URLRequest(
                                            url: WebUri.uri(
                                                Uri.parse(_currentUrl))));
                                  }
                                }),
                              )
                            : const SizedBox(height: 0, width: 0),
                        _showErrorPage
                            ? Center(
                                child: NotFound(
                                    webViewController: _webViewController!,
                                    url: _currentUrl,
                                    title1: 'Page not found',
                                    title2: 'Page not found, please try again'))
                            : const SizedBox(height: 0, width: 0),
                        _slowInternetPage
                            ? Center(
                                child: NotFound(
                                    webViewController: _webViewController!,
                                    url: _currentUrl,
                                    title1: 'Incorrect URL',
                                    title2: 'Incorrect URL, please try again'))
                            : const SizedBox(height: 0, width: 0),
                        // Loading overlay circle
                        _progress < 1.0 && _isValidURL
                            ? LoadingOverlay(
                                progress: _progress,
                              )
                            : const SizedBox.shrink(),
                        DevToolButton(),
                      ],
                    ),
                  )),
            )
          ],
        ));
  }
}
