import 'package:flutter/foundation.dart';

class SavedCookieProvider extends ChangeNotifier {
  String? _savedCookie = "/";

  void setSavedCookie(String? savedCookie) {
    _savedCookie = savedCookie;
    notifyListeners();
  }

  String? get savedCookie => _savedCookie;
}
