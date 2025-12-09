import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_base/constants/javascript.dart';

/// Unified WebView provider that manages controller, loading state, and URL
///
/// This provider combines functionality from:
/// - WebViewControllerProvider: Controller management and navigation
/// - WebViewLoadingProvider: Loading state and progress tracking
/// - WebviewURLProvider: Current URL tracking
class WebViewProvider extends ChangeNotifier {
  // ==================== Controller State ====================
  InAppWebViewController? _controller;

  InAppWebViewController? get controller => _controller;

  void setController(InAppWebViewController? controller) {
    _controller = controller;
    notifyListeners();
  }

  void handleNotification(String payload) async {
    if (_controller != null) {
      _controller!.evaluateJavascript(source: navigate(payload));
    }
  }

  // ==================== Loading State ====================
  double _progress = 0.0;
  bool _hasInitialLoadCompleted = false;
  double get progress => _progress;
  bool get hasInitialLoadCompleted => _hasInitialLoadCompleted;

  void setProgress(double progress) {
    // After initial load completes, don't allow progress to go below 1.0
    // This prevents splash screen from showing again on subsequent navigations
    if (_hasInitialLoadCompleted && progress < 1.0) {
      return; // Don't update progress if it would go below 1.0 after initial load
    }
    if (_progress != progress) {
      _progress = progress;
      // Mark initial load as completed when progress reaches 1.0
      if (progress >= 1.0 && !_hasInitialLoadCompleted) {
        _hasInitialLoadCompleted = true;
      }
      notifyListeners();
    }
  }

  void resetLoading() {
    _progress = 0.0;
    _hasInitialLoadCompleted = false;
    notifyListeners();
  }

  // ==================== URL State ====================
  String _currentUrl = "";

  String get currentUrl => _currentUrl;

  void setCurrentUrl(String url) {
    if (_currentUrl != url) {
      _currentUrl = url;
      notifyListeners();
    }
  }

  // ==================== Reset All ====================
  /// Reset all WebView state (useful when navigating away or restarting)
  void resetAll() {
    _controller = null;
    _progress = 0.0;
    _hasInitialLoadCompleted = false;
    _currentUrl = "";
    notifyListeners();
  }
}
