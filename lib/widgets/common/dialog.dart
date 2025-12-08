import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDialog {
  Future<void> showUpdateDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('앱 업데이트 필요!'),
          content: Text(
            "EasySales의 새로운 버전이 출시되었습니다!\n지금 바로 업데이트하세요!",
            style: TextStyle(fontSize: 13),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                '지금 업데이트',
                style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 16),
              ),
              onPressed: () async {
                PackageInfo packageInfo = await PackageInfo.fromPlatform();
                final Uri iosAppStoreUrl =
                    Uri.parse("https://apps.apple.com/app/id6738642810");
                final Uri androidPlayStoreUrl = Uri.parse(
                    "https://play.google.com/store/apps/details?id=${packageInfo.packageName}");
                if (Platform.isAndroid) {
                  if (await canLaunchUrl(androidPlayStoreUrl)) {
                    launchUrl(androidPlayStoreUrl);
                  }
                  return;
                }
                launchUrl(iosAppStoreUrl);
              },
            ),
          ],
        );
      },
    );
  }
}
