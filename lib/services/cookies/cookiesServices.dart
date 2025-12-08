import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../provider/savedCookieProvider.dart';

void checkExistCookie(BuildContext context) async {
  SharedPreferences pref = await SharedPreferences.getInstance();
  if (context.mounted) {
    context
        .read<SavedCookieProvider>()
        .setSavedCookie(pref.getString('cookies'));
  }
}
