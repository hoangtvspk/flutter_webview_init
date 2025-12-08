import 'package:flutter/material.dart';

double figmaFullHeght = 734 + 34;
double figmaFullWidth = 375;

double perHeight(context, height) {
  return MediaQuery.of(context).size.height * height / figmaFullHeght;
}

double perWidth(context, width) {
  return MediaQuery.of(context).size.width * width / figmaFullWidth;
}

double fullHeight(context) {
  return MediaQuery.of(context).size.height;
}

double fullWidth(context) {
  return MediaQuery.of(context).size.width;
}
