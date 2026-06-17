import 'package:flutter/material.dart';

/// Brand palette — Nutriblend-style vibrant green (#009639).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF009639);
  static const Color primaryLight = Color(0xFF00B84A);
  static const Color primaryDark = Color(0xFF007A2E);
  static const Color primaryMuted = Color(0xFFE8F8EE);
  static const Color accent = Color(0xFF009639);
  static const Color accentLight = Color(0xFF33C966);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F9F6);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color success = Color(0xFF009639);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient drawerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, primaryDark],
  );
}
