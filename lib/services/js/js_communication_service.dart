import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_base/constants/javascript.dart';
import 'package:webview_base/models/web_post_message.dart';
import 'package:webview_base/provider/webview_provider.dart';
import 'package:webview_base/repositories/auth_repository.dart';

/// Service for handling JavaScript communication with WebView
/// Manages route changes, post messages, and contacts access
class JsCommunicationService {
  /// Define JavaScript handler for SPA route changes
  static void defineRouteChangeFunction({
    required InAppWebViewController controller,
    required BuildContext context,
    required AuthRepository authRepository,
    required CookieManager cookieManager,
    required String webViewUrl,
  }) {
    controller.addJavaScriptHandler(
      handlerName: "onRouteChanged",
      callback: (args) {
        String currentUrl = args[0];
        print("SPA navigated to: $currentUrl");

        authRepository.checkUserLoginStatus(
          cookieManager: cookieManager,
          url: webViewUrl,
          name: "USER_INFOR",
        );

        context.read<WebViewProvider>().setCurrentUrl(currentUrl);
      },
    );
  }

  /// Handle JavaScript postMessage events from WebView
  static Future<void> handlePostMessage({
    required InAppWebViewController controller,
    required String webViewUrl,
    required Function({
      required String name,
      required String url,
      String? base64Str,
    }) onDownload,
  }) async {
    print("Setting up WebMessage listener");

    if (defaultTargetPlatform != TargetPlatform.android ||
        await WebViewFeature.isFeatureSupported(
            WebViewFeature.WEB_MESSAGE_LISTENER)) {
      await controller.addWebMessageListener(WebMessageListener(
        jsObjectName: "webviewListener",
        onPostMessage: (message, sourceOrigin, isMainFrame, replyProxy) {
          print("message: $message");
          if (message != null && message.data != null) {
            dynamic postedMessage =
                WebPostMessage.fromJson(jsonDecode(message.data.toString()));
            print('message type: ${postedMessage.type}');

            if (postedMessage.type == 'share') {
              final params = ShareParams(
                title: postedMessage.messageData?.title ?? '',
                uri: Uri.parse(postedMessage.messageData?.url ?? ''),
              );
              SharePlus.instance.share(
                params,
              );
            } else if (postedMessage.type == 'contacts') {
              getContacts(controller: controller);
            } else if (postedMessage.type == 'download-template-base64') {
              onDownload(
                name: postedMessage.messageData?.url ?? '',
                url: postedMessage.messageData?.title ?? '',
                base64Str: postedMessage.messageData?.title ?? '',
              );
            }
          }
        },
      ));
      controller.loadUrl(urlRequest: URLRequest(url: WebUri(webViewUrl)));
    }
  }

  /// Get contacts from device (with permission handling)
  static Future<void> getContacts({
    required InAppWebViewController controller,
  }) async {
    try {
      final statusBefore = await Permission.contacts.status;

      final permissionStatus = await Permission.contacts.request();

      if (permissionStatus == PermissionStatus.permanentlyDenied) {
        controller.evaluateJavascript(source: handleException("Access denied"));
        if (statusBefore == PermissionStatus.denied) {
          // First time denial
        } else {
          openAppSettings();
        }
      } else if (permissionStatus == PermissionStatus.granted) {
        final contacts =
            await FlutterContacts.getContacts(withProperties: true);

        // Convert contacts to JSON format
        List<Map<String, dynamic>> contactsJson = [];
        for (var contact in contacts) {
          var phones = contact.phones;

          if (phones.isEmpty) {
            contactsJson.add({
              'name': contact.displayName,
              'tel': '',
              'id': contact.id,
            });
          } else {
            for (var phone in phones) {
              contactsJson.add({
                'name': contact.displayName,
                'tel': phone.number,
                'id': '${contact.id} ${phone.number}',
              });
            }
          }
        }

        String jsonString = jsonEncode(contactsJson);
        jsonString = jsonString.replaceAll("'", "\\'");
        controller.evaluateJavascript(source: setContacts(jsonString));
      } else if (statusBefore == PermissionStatus.denied &&
          Platform.isAndroid) {
        controller.evaluateJavascript(source: handleException("Access denied"));
      }
    } catch (e) {
      print('Error in getContacts: $e');
    }
  }
}
