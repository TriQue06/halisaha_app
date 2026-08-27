import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ayarlar sekmesinden yönetilen, uygulama geneline yansıyan tercihler.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.textScale = 1.0,
    this.matchNotifications = true,
    this.challengeNotifications = true,
    this.goalkeeperNotifications = false,
  });

  final ThemeMode themeMode;

  /// Uygulama genelindeki yazı boyutu çarpanı (0.8 - 1.4).
  final double textScale;
  final bool matchNotifications;
  final bool challengeNotifications;
  final bool goalkeeperNotifications;

  bool get isDark => themeMode == ThemeMode.dark;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    bool? matchNotifications,
    bool? challengeNotifications,
    bool? goalkeeperNotifications,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
      matchNotifications: matchNotifications ?? this.matchNotifications,
      challengeNotifications: challengeNotifications ?? this.challengeNotifications,
      goalkeeperNotifications: goalkeeperNotifications ?? this.goalkeeperNotifications,
    );
  }
}

/// Tercihleri tutar ve cihazda kalıcı hale getirir.
class SettingsController extends Notifier<AppSettings> {
  static const String _kThemeDark = 'settings.theme_dark';
  static const String _kTextScale = 'settings.text_scale';
  static const String _kMatchNotif = 'settings.notif_match';
  static const String _kChallengeNotif = 'settings.notif_challenge';
  static const String _kGoalkeeperNotif = 'settings.notif_goalkeeper';

  SharedPreferences? _prefs;

  @override
  AppSettings build() {
    // Varsayılan tema: açık (koyu yeşil + beyaz). Kayıtlı tercih varsa
    // asenkron olarak yüklenip state güncellenir.
    _restore();
    return const AppSettings();
  }

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    state = AppSettings(
      themeMode: (prefs.getBool(_kThemeDark) ?? false) ? ThemeMode.dark : ThemeMode.light,
      textScale: prefs.getDouble(_kTextScale) ?? 1.0,
      matchNotifications: prefs.getBool(_kMatchNotif) ?? true,
      challengeNotifications: prefs.getBool(_kChallengeNotif) ?? true,
      goalkeeperNotifications: prefs.getBool(_kGoalkeeperNotif) ?? false,
    );
  }

  void toggleTheme(bool isDark) {
    state = state.copyWith(themeMode: isDark ? ThemeMode.dark : ThemeMode.light);
    _prefs?.setBool(_kThemeDark, isDark);
  }

  void setTextScale(double scale) {
    final double clamped = scale.clamp(0.8, 1.4);
    state = state.copyWith(textScale: clamped);
    _prefs?.setDouble(_kTextScale, clamped);
  }

  void setMatchNotifications(bool value) {
    state = state.copyWith(matchNotifications: value);
    _prefs?.setBool(_kMatchNotif, value);
  }

  void setChallengeNotifications(bool value) {
    state = state.copyWith(challengeNotifications: value);
    _prefs?.setBool(_kChallengeNotif, value);
  }

  void setGoalkeeperNotifications(bool value) {
    state = state.copyWith(goalkeeperNotifications: value);
    _prefs?.setBool(_kGoalkeeperNotif, value);
  }
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
