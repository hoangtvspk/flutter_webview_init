import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_base/utils/permission.dart';

/// Mixin for handling file downloads in WebView
/// Provides download functionality with progress tracking and snackbar notifications
mixin WebViewDownloadMixin<T extends StatefulWidget> on State<T> {
  /// Handle file download with progress tracking
  ///
  /// Parameters:
  /// - [name]: Display name for the file
  /// - [url]: Download URL or base64 string
  /// - [base64Str]: Optional base64 encoded file content
  Future<void> handleDownload({
    required String name,
    required String url,
    String? base64Str,
  }) async {
    // Get ScaffoldMessenger early before any async operations
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();

    try {
      final streamController = StreamController<String>.broadcast();

      Dio dio = Dio();
      String fileName;
      if (url.toString().lastIndexOf('?') > 0) {
        fileName = url.toString().substring(url.toString().lastIndexOf('/') + 1,
            url.toString().lastIndexOf('?'));
      } else {
        fileName =
            url.toString().substring(url.toString().lastIndexOf('/') + 1);
      }
      String savePath = await _getFilePath(base64Str != null ? name : fileName);

      if (!mounted) return;

      final downloadingSnackBarController = scaffoldMessenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 30),
          content: StreamBuilder<String>(
            stream: streamController.stream,
            builder: (context, snapshot) {
              return Row(
                children: [
                  const Icon(
                    Icons.download,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Number: ${snapshot.data ?? 0}'),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                    name,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ))
                ],
              );
            },
          ),
        ),
      );

      // Handle base64 or URL download
      if (base64Str != null) {
        try {
          final base64Data = base64Str.split(',').last;
          final bytes = base64Decode(base64Data);

          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$name');
          await file.writeAsBytes(bytes);
          streamController.add('100%');
          print('✅ File saved to: ${file.path}');
          savePath = file.path;
          Future.delayed(const Duration(seconds: 1), () {
            streamController.close();
            downloadingSnackBarController.close();
          });
        } catch (e) {
          print('❌ Failed to save file: $e');
          streamController.close();
        }
      } else {
        try {
          await dio.download(
            url.toString(),
            savePath,
            onReceiveProgress: (received, total) {
              if (total <= 0) return;
              String pc = (received / total * 100).toStringAsFixed(0);
              if (int.parse(pc) <= 100) {
                streamController.add('$pc%');
              }
              if (int.parse(pc) == 100) {
                Future.delayed(const Duration(seconds: 1), () {
                  streamController.close();
                  downloadingSnackBarController.close();
                });
              }
            },
          );
        } catch (error) {
          streamController.close();
          downloadingSnackBarController.close();
          rethrow;
        }
      }

      if (!mounted) return;

      // Show success snackbar with open button
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.download,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.done,
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () async {
                  await OpenFile.open(savePath);
                },
                child: Text(
                  'Open',
                  style: TextStyle(
                      color: Colors.blue[600],
                      decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                name,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ))
            ],
          ),
        ),
      );
    } on Exception catch (e) {
      print(e);
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.download,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.cancel_sharp,
              color: Colors.red,
            ),
            const SizedBox(width: 10),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
              name,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ))
          ],
        ),
      ));
    }
  }

  /// Show error snackbar
  void showSnackBarErr(String content) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error,
              color: Colors.red,
            ),
            const SizedBox(width: 16),
            Text(
              content,
              style: const TextStyle(color: Colors.black54),
            )
          ],
        ),
        showCloseIcon: true,
        closeIconColor: Colors.black54,
        backgroundColor: Colors.grey[100],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 150,
            left: 20,
            right: 20),
      ),
    );
  }

  /// Get file path for saving downloaded files
  Future<String> _getFilePath(String uniqueFileName) async {
    String path = '';
    String externalStorageDirPath = '';

    if (Platform.isAndroid) {
      try {
        // For Android 10+, use app-specific directory which doesn't require permissions
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Create Downloads folder in app-specific storage
          final downloadDir = Directory('${directory.path}/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          externalStorageDirPath = downloadDir.path;
        } else {
          // Fallback to internal storage
          final internalDir = await getApplicationDocumentsDirectory();
          externalStorageDirPath = internalDir.path;
        }
      } catch (e) {
        print('Error getting storage directory: $e');
        final directory = await getApplicationDocumentsDirectory();
        externalStorageDirPath = directory.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }

    path = '$externalStorageDirPath/$uniqueFileName';
    return path;
  }

  /// Handle download start request
  Future<void> onDownloadStartRequest({
    required DownloadStartRequest request,
    required Function({bool? isLoading, double? progress}) onUpdateState,
  }) async {
    onUpdateState(isLoading: false, progress: 1);

    enableStoragePermision().then((status) async {
      String url = request.url.toString();
      String fileName = request.suggestedFilename.toString();

      if (status == true) {
        handleDownload(url: url, name: fileName);
      } else {
        openAppSettings();
      }
    });
  }
}
