import 'package:flutter/foundation.dart';

class WebViewLoadingProvider extends ChangeNotifier {
  bool _isLoading = true;
  double _progress = 0.0;

  bool get isLoading => _isLoading;
  double get progress => _progress;

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void setProgress(double progress) {
    if (_progress != progress) {
      _progress = progress;
      notifyListeners();
    }
  }

  void reset() {
    _isLoading = true;
    _progress = 0.0;
    notifyListeners();
  }
}
