import '../constants/common.dart';

import 'package:flutter/material.dart';

extension CustomIcons on ColorScheme {
  String get noInternetIcon => '${iconPath}no_internet.svg';
  String get closeIcon => '${iconPath}close_icon.svg';

  String get exitIcon => '${iconPath}exit_app.svg';
}
