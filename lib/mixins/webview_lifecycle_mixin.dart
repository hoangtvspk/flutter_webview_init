import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_base/config/env_config.dart';
import 'package:webview_base/constants/javascript.dart';
import 'package:webview_base/helpers/webview_helper.dart';
import 'package:webview_base/provider/navigation_bar_provider.dart';
import 'package:webview_base/provider/webview_provider.dart';
import 'package:webview_base/repositories/auth_repository.dart';
import 'package:webview_base/services/cookies/cookies_services.dart';
import 'package:webview_base/services/js_communication_service.dart';

/// Mixin for WebView lifecycle event handlers
/// Contains business logic for WebView events: onWebViewCreated, onLoadStart, onLoadStop, etc.
///
/// This separates lifecycle handling from UI code
mixin WebViewLifecycleMixin<T extends StatefulWidget> on State<T> {
  final AuthRepository _authRepository = AuthRepository();
  final CookieManager _cookieManager = CookieManager.instance();
  final WebViewHelper _webViewHelper = WebViewHelper();
  final String _webViewUrl = EnvConfig.instance.webviewUrl;

  // ==================== State Variables ====================
  int _previousScrollY = 0;

  // ==================== Controller Setup ====================

  /// Set WebView controller in provider
  void setController({required InAppWebViewController controller}) {
    Provider.of<WebViewProvider>(context, listen: false)
        .setController(controller);
  }

  // ==================== Utility Functions ====================

  /// Validate URL and return whether it's valid
  bool validateUrl(String url) {
    return Uri.tryParse(url)?.isAbsolute ?? false;
  }

  // ==================== Scroll Handling ====================

  /// Handle WebView scroll events
  void onScrollChanged({required int y}) {
    try {
      int currentScrollY = y;

      if (currentScrollY > _previousScrollY) {
        if (!context
            .read<NavigationBarProvider>()
            .animationController
            .isAnimating) {
          context.read<NavigationBarProvider>().animationController.forward();
        }
      } else {
        if (!context
            .read<NavigationBarProvider>()
            .animationController
            .isAnimating) {
          context.read<NavigationBarProvider>().animationController.reverse();
        }
      }
      _previousScrollY = currentScrollY;
    } catch (e) {
      print(e);
    }
  }

  // ==================== WebView Created ====================

  /// Handle WebView creation - setup all listeners and configurations
  Future<void> onWebViewCreated({
    required InAppWebViewController controller,
    required Function(
            {required String name, required String url, String? base64Str})
        onDownload,
    required Function(InAppWebViewController) onControllerInitialized,
  }) async {
    onControllerInitialized(controller);
    setController(controller: controller);

    await restoreCookies(_webViewUrl, _cookieManager);

    JsCommunicationService.defineRouteChangeFunction(
      controller: controller,
      // ignore: use_build_context_synchronously
      context: context,
      authRepository: _authRepository,
      cookieManager: _cookieManager,
      webViewUrl: _webViewUrl,
    );

    await markAccessByWebview(
      webViewUrl: _webViewUrl,
      cookieManager: _cookieManager,
    );

    await JsCommunicationService.handlePostMessage(
      controller: controller,
      // ignore: use_build_context_synchronously
      context: context,
      onDownload: onDownload,
    );
  }

  // ==================== Load Start ====================

  /// Handle WebView load start
  void onLoadStart({
    required InAppWebViewController controller,
    required WebUri? url,
    required VoidCallback onUpdate,
    bool isOpenDialog = false,
    BuildContext? dialogContext,
  }) {
    print('----------GET URL: $url');

    // Reset loading state if needed
    final loadingProvider =
        Provider.of<WebViewProvider>(context, listen: false);
    if (loadingProvider.progress < 1.0) {
      loadingProvider.resetLoading();
    }

    onUpdate();

    context.read<WebViewProvider>().setCurrentUrl(url.toString());

    // Close dialog if open
    if (isOpenDialog == true && dialogContext != null) {
      Navigator.of(dialogContext).pop();
    }
  }

  // ==================== Load Stop ====================

  /// Handle WebView load stop
  Future<void> onLoadStop({
    required InAppWebViewController controller,
    required WebUri? url,
    required InAppWebViewController? webViewController,
    required VoidCallback onUpdate,
    required PullToRefreshController? pullToRefreshController,
  }) async {
    if (webViewController != null) {
      Uri? uri = url?.uriValue;
      if (uri != null) {
        await _webViewHelper.handleDeepLink(
          webViewController: webViewController,
          path: uri.path + (uri.hasQuery ? '?${uri.query}' : ''),
        );
      }
    }

    // await _authRepository.checkUserLoginStatus(
    //   cookieManager: _cookieManager,
    //   url: _webViewUrl,
    //   name: "USER_INFOR",
    // );

    await controller.evaluateJavascript(source: listenRouterChange);

    print("stop successful");
    onUpdate();

    pullToRefreshController?.endRefreshing();
  }

  // ==================== Navigation Policy ====================
  // Get navigation action policy for specific URLs
  // Handles OAuth redirects, intent URLs, and custom schemes
  Future<NavigationActionPolicy> getNavigationPolicy(WebUri? uri) async {
    // Handle OAuth URLs (Google, Kakao, Naver)
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
          print("Failed to launch OAuth URL");
        }
      } catch (e) {
        print("Error launching OAuth: $e");
      }
      return NavigationActionPolicy.CANCEL;
    }

    // Handle Naver custom schemes
    if (uri != null &&
        (uri.scheme == "naversearchthirdlogin" || uri.scheme == "nidlogin")) {
      uri.replace(scheme: 'naversearchthirdlogin');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      return NavigationActionPolicy.CANCEL;
    }

    // Handle intent URLs
    if (uri.toString().contains("intent:")) {
      try {
        Uri appUri = Uri.parse(
            _webViewHelper.convertAndAdjustUrl(uri.toString()).toString());
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri,
              mode: LaunchMode.externalNonBrowserApplication);
        } else {
          // Try to open Play Store if app is not installed
          String? package = _webViewHelper.getIntentPackage(uri.toString());
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
        print("Error handling intent URL: $e");
        return NavigationActionPolicy.CANCEL;
      }
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  // ==================== Error Handling ====================

  /// Handle WebView errors
  Future<void> onReceivedError({
    required InAppWebViewController controller,
    required WebResourceRequest request,
    required WebResourceError error,
    required PullToRefreshController? pullToRefreshController,
    required InAppWebViewController? webViewController,
    required Function(String) onShowError,
    required Function({
      double? progress,
      bool? showNoInternet,
      bool? noInternet,
    }) onUpdateState,
  }) async {
    pullToRefreshController?.endRefreshing();
    print("onReceivedError ${error.description}");

    onUpdateState(progress: 1);

    final uri = request.url;

    // Handle specific error codes
    if (error.description ==
        "The operation couldn't be completed. (NSURLErrorDomain error -999.)") {
      webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri.uri(Uri.parse(_webViewUrl))));
      return;
    }

    // Handle unsupported URL on iOS
    if (Platform.isIOS &&
        error.description == 'unsupported URL' &&
        WebViewHelper.isNonWebsiteUrl(uri.toString())) {
      // This should be handled by navigation mixin or helper,
      // but for now we'll use the callback or helper directly if possible.
      // Since we need to call handleNonWebsiteUrl which is in NavigationMixin,
      // we might need to delegate this back or assume the mixin is present.
      // For now, we'll assume the caller handles the navigation logic if we return,
      // but here we need to execute it.
      // Since we can't easily call NavigationMixin methods here without casting,
      // we'll rely on the helper.

      if (await canLaunchUrl(uri)) {
        print("launch unsupport url $uri");
        await launchUrl(uri);
      } else {
        webViewController?.stopLoading();
        onShowError("앱이 설치되어 있지 않습니다.");
      }
      return;
    }

    if (Platform.isAndroid) {
      if (error.description == 'net::ERR_UNKNOWN_URL_SCHEME') {
        webViewController?.goBack();
        return;
      }

      if (error.description == 'net::ERR_INTERNET_DISCONNECTED' ||
          error.description == 'net::ERR_TIMED_OUT') {
        onUpdateState(showNoInternet: true, noInternet: true);
        return;
      }
    }

    if (Platform.isIOS &&
        error.description == 'The Internet connection appears to be offline.') {
      onUpdateState(showNoInternet: true, noInternet: true);
      return;
    }
  }

  // ==================== History & Console ====================

  /// Handle visited history update
  void onUpdateVisitedHistory({
    required WebUri? url,
    required Function(String) onUpdateUrl,
  }) {
    onUpdateUrl(url.toString());
  }

  /// Handle console messages
  void onConsoleMessage(ConsoleMessage message) {
    print('------console-log: ${message.message}');
  }
}
