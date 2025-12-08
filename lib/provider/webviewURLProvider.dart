import 'package:flutter/foundation.dart';

class WebviewURLProvider extends ChangeNotifier {
  String _currentUrl = "";

  void setCurrentURL(String currentURL) {
    _currentUrl = currentURL;
    notifyListeners();
  }

  String get currentURL => _currentUrl;
}
