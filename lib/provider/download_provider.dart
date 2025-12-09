import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webview_base/services/rest_api/download_service.dart';

/// Provider for managing download UI state
/// Handles download progress, status, and UI notifications
class DownloadProvider extends ChangeNotifier {
  final DownloadService _service = DownloadService();

  // ==================== State Variables ====================
  String _currentProgress = '0%';
  String? _currentFileName;
  DownloadStatus _status = DownloadStatus.idle;
  String? _errorMessage;
  String? _successFilePath;

  // ==================== Getters ====================
  bool get isDownloading => _status == DownloadStatus.downloading;
  String get progress => _currentProgress;
  String? get fileName => _currentFileName;
  DownloadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get successFilePath => _successFilePath;
  bool get hasError => _status == DownloadStatus.error;
  bool get hasSuccess => _status == DownloadStatus.success;

  // ==================== Download Actions ====================

  StreamController<String>? _streamController;

  /// Start a new download
  Future<void> startDownload({
    required String url,
    required String name,
    String? base64Str,
  }) async {
    _currentFileName = name;
    _status = DownloadStatus.downloading;
    _currentProgress = '0%';
    _errorMessage = null;
    _successFilePath = null;
    notifyListeners();

    _streamController = StreamController<String>.broadcast();

    try {
      final path = await _service.downloadFile(
        url: url,
        name: name,
        base64Str: base64Str,
        onProgress: (progress) {
          _currentProgress = progress;
          notifyListeners();
        },
        streamController: _streamController!,
      );

      if (path != null) {
        _status = DownloadStatus.success;
        _successFilePath = path;
      } else {
        _status = DownloadStatus.error;
        _errorMessage = 'Download failed';
      }
    } catch (e) {
      _status = DownloadStatus.error;
      _errorMessage = e.toString();
    } finally {
      await _streamController?.close();
      _streamController = null;
      notifyListeners();
    }
  }

  /// Open the downloaded file
  Future<void> openFile() async {
    if (_successFilePath != null) {
      await _service.openFile(_successFilePath!);
    }
  }

  /// Clear download state
  void clearState() {
    _status = DownloadStatus.idle;
    _currentProgress = '0%';
    _currentFileName = null;
    _errorMessage = null;
    _successFilePath = null;
    _streamController?.close();
    _streamController = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _streamController?.close();
    super.dispose();
  }

  /// Show error snackbar
  void showError(String message) {
    _status = DownloadStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}

enum DownloadStatus {
  idle,
  downloading,
  success,
  error,
}
