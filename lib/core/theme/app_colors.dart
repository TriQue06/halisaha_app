import 'package:flutter/material.dart';

/// RakipVar renk paleti.
///
/// Açık tema  : Koyu yeşil + beyaz
/// Koyu tema  : Koyu yeşil + koyu gri / siyah
abstract final class AppColors {
  // --- Marka yeşilleri -------------------------------------------------
  static const Color primaryGreen = Color(0xFF0B6B3A); // ana koyu yeşil
  static const Color deepGreen = Color(0xFF06351E); // en koyu ton (app bar, gradient)
  static const Color midGreen = Color(0xFF12995A); // vurgu / seçili durum
  static const Color lime = Color(0xFFB8F24A); // aksan (saha çizgisi hissi)

  // --- Açık tema -------------------------------------------------------
  static const Color lightBackground = Color(0xFFF3F6F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEAF1EC);
  static const Color lightBorder = Color(0xFFDCE5DF);
  static const Color lightTextPrimary = Color(0xFF10201A);
  static const Color lightTextSecondary = Color(0xFF5F6F67);

  // --- Koyu tema -------------------------------------------------------
  static const Color darkBackground = Color(0xFF0B0F0D);
  static const Color darkSurface = Color(0xFF151B18);
  static const Color darkSurfaceAlt = Color(0xFF1E2723);
  static const Color darkBorder = Color(0xFF2A3631);
  static const Color darkTextPrimary = Color(0xFFECF3EE);
  static const Color darkTextSecondary = Color(0xFF9BAAA2);

  // --- Anlamsal renkler ------------------------------------------------
  static const Color win = Color(0xFF17A45C); // Galibiyet
  static const Color draw = Color(0xFFE0A21B); // Beraberlik
  static const Color loss = Color(0xFFD9453D); // Mağlubiyet
  static const Color info = Color(0xFF2E7BD6);
  static const Color star = Color(0xFFF5B301);
}
