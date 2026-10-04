import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  static const page = EdgeInsets.all(md);
  static const card = EdgeInsets.all(lg);
  static const section = EdgeInsets.symmetric(vertical: xl);
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

abstract final class AppElevation {
  static const double card = 1;
  static const double overlay = 8;
  static const double dialog = 12;
}
