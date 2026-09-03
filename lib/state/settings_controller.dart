import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ayarlar sekmesinden yönetilen, uygulama geneline yansıyan tercihler.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
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

  /// Yalnızca "koyu seçili mi" bilgisi; sistem modunda anlamı yoktur,
  /// gerçek görünüm için `Theme.of(context).brightness` kullanılmalı.
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
  /// Eski sürümde tema yalnızca açık/koyu bool'uydu. Yeni anahtar üç
  /// değerli (system/light/dark); eskisi ilk açılışta göç ettiriliyor.
  static const String _kThemeDark = 'settings.theme_dark';
  static const String _kThemeMode = 'settings.theme_mode';
  static const String _kTextScale = 'settings.text_scale';
  static const String _kMatchNotif = 'settings.notif_match';
  static const String _kChallengeNotif = 'settings.notif_challenge';
  static const String _kGoalkeeperNotif = 'settings.notif_goalkeeper';

  SharedPreferences? _prefs;

  @override
  AppSettings build() {
    // Varsayılan tema: cihazın kendi ayarı. Kayıtlı tercih varsa
    // asenkron olarak yüklenip state güncellenir.
    _restore();
    return const AppSettings();
  }

  static ThemeMode _modeFromName(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _modeToName(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    // Yeni anahtar yoksa eski bool'dan göç et; o da yoksa sistem.
    final String? storedMode = prefs.getString(_kThemeMode);
    final ThemeMode mode = storedMode != null
        ? _modeFromName(storedMode)
        : prefs.containsKey(_kThemeDark)
            ? (prefs.getBool(_kThemeDark)! ? ThemeMode.dark : ThemeMode.light)
            : ThemeMode.system;

    state = AppSettings(
      themeMode: mode,
      textScale: prefs.getDouble(_kTextScale) ?? 1.0,
      matchNotifications: prefs.getBool(_kMatchNotif) ?? true,
      challengeNotifications: prefs.getBool(_kChallengeNotif) ?? true,
      goalkeeperNotifications: prefs.getBool(_kGoalkeeperNotif) ?? false,
    );
  }

  /// Tema modunu ayarlar (sistem / açık / koyu).
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs?.setString(_kThemeMode, _modeToName(mode));
  }

  /// Açık ↔ koyu arasında gider gelir; sistem modundayken o anki
  /// görünümün tersine geçer.
  void toggleTheme(bool isDark) => setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);

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
