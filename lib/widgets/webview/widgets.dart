import 'dart:io';

import 'package:webview_base/config/env_config.dart';
import 'package:webview_base/provider/webViewControllerProvider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/svg.dart';
import 'package:webview_base/helpers/Themes.dart';
import 'package:webview_base/helpers/icons.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../provider/appGlobalKey.dart';
import '../../screens/SplashScreen.dart';
import '../ExpandingActionButton.dart';

class WebviewWidgets {
  void createWindow({
    required int windowId,
    required void Function(void Function()) setState,
    required bool isOpenDialog,
    required bool isNewWindowLoading,
    required bool allowClosePopUp,
    required BuildContext context,
    required BuildContext? dialogContext,
    required String url,
    required InAppWebViewSettings options,
    required String webinitialUrl,
  }) async {
    final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers = {
      Factory(() => EagerGestureRecognizer())
    };

    final provider =
        Provider.of<WebViewControllerProvider>(context, listen: false);
    InAppWebViewController? webViewController = provider.controller;

    late InAppWebViewController windowController;

    UniqueKey key = UniqueKey();
    setState(() {
      isOpenDialog = true;
      isNewWindowLoading = true;
    });
    Future.delayed(
        const Duration(seconds: 3),
        (() => {
              setState(
                () {
                  allowClosePopUp = true;
                },
              )
            }));

    showModalBottomSheet<void>(
      isDismissible: allowClosePopUp,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10), topRight: Radius.circular(10))),
      builder: (BuildContext context) {
        dialogContext = context;
        return StatefulBuilder(builder: (context, setState) {
          return InkWell(
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () {
              allowClosePopUp ? Navigator.of(context).pop() : null;
            },
            child: Container(
              alignment: Alignment.bottomCenter,
              height: fullHeight(context),
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10))),
                height: fullHeight(context) * 0.83,
                width: fullWidth(context),
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  InkWell(
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () {
                      allowClosePopUp ? Navigator.of(context).pop() : null;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding:
                                EdgeInsets.only(right: perHeight(context, 20)),
                            child: SvgPicture.asset(
                                Theme.of(context).colorScheme.closeIcon,
                                width: 20,
                                height: 20),
                          ),
                        ),
                        SizedBox(
                          height: perHeight(context, 20),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.8,
                              width: MediaQuery.of(context).size.width,
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      topRight: Radius.circular(10))),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: perHeight(context, 50),
                                    width: perHeight(context, 50),
                                    child: (isNewWindowLoading == true)
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : const SizedBox(height: 0, width: 0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(10.0),
                      ),
                      child: InAppWebView(
                        key: key,
                        initialUrlRequest:
                            URLRequest(url: WebUri.uri(Uri.parse(url))),
                        gestureRecognizers: gestureRecognizers,
                        windowId: windowId,
                        initialSettings: options,
                        onWebViewCreated: (InAppWebViewController controller) {
                          windowController = controller;
                        },
                        onCloseWindow: (controller) => {print('close window')},
                        onLoadStart: (windowController, loadUrl) {},
                        shouldOverrideUrlLoading:
                            (controller, navigationAction) async {
                          Map<String, String> params =
                              navigationAction.request.url!.queryParameters;
                          if (params['token_version_id'] != null &&
                              params['enc_data'] != null &&
                              params['integrity_value'] != null &&
                              !navigationAction.request.url!
                                  .toString()
                                  .toString()
                                  .contains("nice.checkplus.co.kr") &&
                              Platform.isIOS) {
                            webViewController!.loadUrl(
                                urlRequest: URLRequest(
                                    url: navigationAction.request.url!));

                            Future.delayed(const Duration(milliseconds: 200),
                                () {
                              Navigator.of(context).pop();
                            });
                            return NavigationActionPolicy.CANCEL;
                          }
                          return NavigationActionPolicy.ALLOW;
                        },
                        onLoadStop: (controller, loadUrl) async {
                          if (loadUrl.toString().contains("prompt=none")) {
                            webViewController!.loadUrl(
                                urlRequest: URLRequest(
                                    url: WebUri.uri(Uri.parse(
                                        '${webinitialUrl}join/join'))));
                          }

                          setState(() {
                            isNewWindowLoading = false;
                          });
                        },
                        onReceivedError: (controller, url, code) {
                          Future.delayed(const Duration(milliseconds: 1000),
                              () {
                            Navigator.of(context).pop();
                          });

                          print(
                              '---load error----==$code ---${code.description}');
                        },
                        onCreateWindow: (controller, createWindowAction) async {
                          createWindow(
                              windowId: windowId,
                              setState: setState,
                              isOpenDialog: isOpenDialog,
                              isNewWindowLoading: isNewWindowLoading,
                              allowClosePopUp: allowClosePopUp,
                              context: context,
                              dialogContext: dialogContext,
                              url: url,
                              options: options,
                              webinitialUrl: webinitialUrl);
                          return true;
                        },
                        onProgressChanged: (controller, progress) {},
                        onConsoleMessage: (controller, message) {
                          print('------console-log: ${message.message}');
                        },
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          );
        });
      },
    ).then((value) {
      setState(() {
        isOpenDialog = false;
      });
    });
  }

  static Widget toast(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        color: Colors.blueAccent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check,
            color: Colors.white,
          ),
          const SizedBox(
            width: 12.0,
          ),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }

  static Future<void> showEnterUrlDialog(BuildContext context) async {
    TextEditingController textEditingController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter URL'),
          content: SingleChildScrollView(
              child: Form(
            key: formKey,
            child: ListBody(
              children: <Widget>[
                TextFormField(
                  validator: (website) {
                    String pattern =
                        r'^((?:.|\n)*?)((http:\/\/www\.|https:\/\/www\.|http:\/\/|https:\/\/)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)([-A-Z0-9.]+)(/[-A-Z0-9+&@#/%=~_|!:,.;]*)?(\?[A-Z0-9+&@#/%=~_|!:‌​,.;]*)?)';
                    RegExp regExp = RegExp(pattern);
                    if (website!.isEmpty) {
                      return "Please enter your URL";
                    } else if (!(regExp.hasMatch(website))) {
                      return "Invalid URL";
                    } else {
                      return null;
                    }
                  },
                  controller: textEditingController,
                  decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.blue,
                        ),
                      ),
                      border: OutlineInputBorder(
                          borderSide: BorderSide(
                        color: Colors.grey,
                      )),
                      labelStyle: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.w500),
                      floatingLabelStyle: TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.w500),
                      labelText: "Enter your url"),
                ),
              ],
            ),
          )),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 18),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Go!',
                style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 18),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop();
                  EnvConfig.initialize(textEditingController.text);
                  navigatorKey.currentState!.pushReplacement(
                      MaterialPageRoute(builder: (_) => SplashScreen()));
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget floatingActionButton(
      {required BuildContext context,
      required webviewHelper,
      required FToast fToast,
      PackageInfo? packageInfo,
      String? env}) {
    return ExpandableFab(
      distance: 112,
      children: [
        ElevatedButton(
          onPressed: () {
            webviewHelper.handleCopy(fToast);
          },
          style: TextButton.styleFrom(backgroundColor: Colors.blue),
          child: Text(
            "Copy FCM Token",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            showEnterUrlDialog(context);
          },
          style: TextButton.styleFrom(backgroundColor: Colors.blue),
          child: Text(
            "Enter URL",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
