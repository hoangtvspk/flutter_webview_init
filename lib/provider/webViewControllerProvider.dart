import 'package:webview_base/constants/javascript.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewControllerProvider with ChangeNotifier {
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
}
