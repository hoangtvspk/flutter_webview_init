import 'package:flutter/material.dart';
import '../helpers/Colors.dart';

class AppThemes {
  static final lightTheme = ThemeData(
    scaffoldBackgroundColor: backgroundColorLightTheme,
    colorScheme: const ColorScheme.light(),
    fontFamily: 'SegUI',
    primarySwatch: primaryColors,
    primaryColor: primaryColor,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
          color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
      bodyMedium: TextStyle(color: primaryColor, fontSize: 16),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentColor,
    ),
    iconTheme: const IconThemeData(color: primaryColor),
    cardColor: whiteColor,
    appBarTheme: const AppBarTheme(
        backgroundColor: whiteColor,
        titleTextStyle: TextStyle(
            color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
        iconTheme: IconThemeData(color: primaryColor)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
        linearTrackColor: Color(0xFFFD41B4),
        color: Color(0xFF6A05FE),
        refreshBackgroundColor: Color(0xFFF37B46)),
    highlightColor: primaryColor.withOpacity(0.2),
    indicatorColor: accentColor,
    shadowColor: Colors.grey[400],
  );
}
