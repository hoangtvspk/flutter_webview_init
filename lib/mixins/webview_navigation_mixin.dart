import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_base/provider/navigation_bar_provider.dart';
import 'package:webview_base/widgets/webview/webview_window.dart';

/// Mixin for WebView navigation logic
/// Handles back navigation and exit app functionality
mixin WebViewNavigationMixin<T extends StatefulWidget> on State<T> {
  // Abstract method to show error snackbar (implemented by WebViewDownloadMixin or State)
  void showSnackBarErr(String content);

  /// Handle exit app or back navigation
  ///
  /// Returns true if app should exit, false otherwise
  ///
  /// Parameters:
  /// - [validURL]: Whether current URL is valid
  /// - [webViewController]: The WebView controller
  Future<bool> handleExitOrBack({
    required bool validURL,
    required InAppWebViewController? webViewController,
  }) async {
    if (!mounted) return true;

    // Reverse navigation bar animation
    context.read<NavigationBarProvider>().animationController.reverse();

    if (!validURL) {
      return Future.value(true);
    }

    if (webViewController == null) {
      return Future.value(true);
    }

    if (await webViewController.canGoBack()) {
      webViewController.goBack();
      return Future.value(false);
    } else {
      return Future.value(true);
    }
  }

  /// Handle non-website URLs (e.g. custom schemes)
  Future<void> handleNonWebsiteUrl({
    required Uri uri,
    required InAppWebViewController? webViewController,
  }) async {
    if (await canLaunchUrl(uri)) {
      print("launch unsupport url $uri");
      await launchUrl(uri);
    } else {
      webViewController?.stopLoading();
      showSnackBarErr("앱이 설치되어 있지 않습니다.");
    }
  }

  /// Handle create window request (popups)
  Future<bool> handleCreateWindow({
    required CreateWindowAction createWindowRequest,
    required WebviewWindow webviewWindow,
    required bool isOpenDialog,
    required bool isNewWindowLoading,
    required bool allowClosePopUp,
    required BuildContext? dialogContext,
    required String url,
    required InAppWebViewSettings options,
    required Function(bool isOpenDialog) setIsOpenDialog,
    required Function(bool isNewWindowLoading) setIsNewWindowLoading,
    required Function(bool allowClosePopUp) setAllowClosePopUp,
  }) async {
    final webUri = createWindowRequest.request.url;

    // Check for file extensions
    if (webUri.toString().contains(
        RegExp(r'\.(pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|txt|csv)$'))) {
      print("downloading file");
      // Prevent the webview from loading the URL
      return false;
    }

    // Check for OAuth URLs
    if (webUri != null &&
        (webUri
                .toString()
                .contains("https://accounts.google.com/o/oauth2/v2/auth") ||
            webUri
                .toString()
                .contains("https://kauth.kakao.com/oauth/authorize") ||
            webUri
                .toString()
                .contains("https://nid.naver.com/oauth2.0/authorize"))) {
      return false;
    }

    if (Platform.isAndroid) {
      return false;
    }

    print('onCreateWindow $webUri');
    webviewWindow.createWindow(
        windowId: createWindowRequest.windowId,
        isOpenDialog: isOpenDialog,
        isNewWindowLoading: isNewWindowLoading,
        allowClosePopUp: allowClosePopUp,
        setIsOpenDialog: setIsOpenDialog,
        setIsNewWindowLoading: setIsNewWindowLoading,
        setAllowClosePopUp: setAllowClosePopUp,
        context: context,
        dialogContext: dialogContext,
        url: url,
        options: options,
        webinitialUrl: 'webinitialUrl');
    return true;
  }
}
