import 'package:flutter/foundation.dart';

class WebViewLoadingProvider extends ChangeNotifier {
  bool _isLoading = true;
  double _progress = 0.0;
  bool _hasInitialLoadCompleted = false;

  bool get isLoading => _isLoading;
  double get progress => _progress;
  bool get hasInitialLoadCompleted => _hasInitialLoadCompleted;

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

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

  void reset() {
    _isLoading = true;
    _progress = 0.0;
    _hasInitialLoadCompleted = false;
    notifyListeners();
  }
}
