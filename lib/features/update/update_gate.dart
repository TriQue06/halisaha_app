import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';

/// Zorunlu güncelleme kontrolü.
///
/// Açılışta Supabase'deki `app_config` tablosundan platformun en düşük
/// desteklenen sürümünü okur (`min_version_android` / `min_version_ios`).
/// Yüklü sürüm bundan eskiyse uygulama yerine "Güncelleme gerekli" ekranı
/// gösterilir.
///
/// Kontrol arka planda yapılır ve [child]'ı bekletmez. Bağlantı yoksa ya da
/// ayar okunamazsa uygulama normal açılır (kullanıcı kilitlenmesin).
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  String? _storeUrl;
  bool _required = false;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    if (kIsWeb) return;
    final String platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => '',
    };
    if (platform.isEmpty) return;

    try {
      final List<dynamic> rows = await Supabase.instance.client
          .from('app_config')
          .select('key, value')
          .inFilter('key', <String>['min_version_$platform', 'store_url_$platform'])
          .timeout(const Duration(seconds: 8));
      final Map<String, String> config = <String, String>{
        for (final dynamic r in rows)
          (r as Map<String, dynamic>)['key'] as String: (r['value'] as String?) ?? '',
      };

      final String? minVersion = config['min_version_$platform'];
      if (minVersion == null || minVersion.isEmpty) return;

      final PackageInfo info = await PackageInfo.fromPlatform();
      if (!isVersionOlder(info.version, minVersion)) return;

      if (!mounted) return;
      setState(() {
        _required = true;
        _storeUrl = config['store_url_$platform'];
      });
    } catch (_) {
      // Ayar okunamadı: uygulamayı engelleme.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_required) return ForceUpdateScreen(storeUrl: _storeUrl);
    return widget.child;
  }
}

/// [installed] sürümü [minimum]'dan eski mi? ("1.0.6" < "1.0.7").
///
/// Sadece noktalı sayılara bakar; "+12" gibi derleme numarası ve sayı
/// olmayan ekler yok sayılır. Okunamayan sürümde false döner.
bool isVersionOlder(String installed, String minimum) {
  List<int>? parse(String v) {
    final String core = v.trim().split('+').first.split('-').first;
    if (core.isEmpty) return null;
    final List<int> parts = <int>[];
    for (final String p in core.split('.')) {
      final int? n = int.tryParse(p);
      if (n == null) return null;
      parts.add(n);
    }
    return parts;
  }

  final List<int>? a = parse(installed);
  final List<int>? b = parse(minimum);
  if (a == null || b == null) return false;
  final int len = a.length > b.length ? a.length : b.length;
  for (int i = 0; i < len; i++) {
    final int x = i < a.length ? a[i] : 0;
    final int y = i < b.length ? b[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}

/// "Güncelleme gerekli" ekranı. Geri dönülemez; tek çıkış mağaza.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, this.storeUrl});

  final String? storeUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? url = (storeUrl == null || storeUrl!.trim().isEmpty) ? null : storeUrl!.trim();
    final bool isIos = defaultTargetPlatform == TargetPlatform.iOS;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.primaryGreen,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Image.asset(
                    'assets/icon/app_icon_foreground.png',
                    width: 150,
                    height: 150,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                  ),
                  Text(
                    'Güncelleme gerekli',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Japon Kale\'nin yeni bir sürümü var. Devam etmek için '
                    'uygulamayı ${isIos ? 'App Store' : 'Google Play'}\'den güncelle.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 28),
                  if (url != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryGreen,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () => launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.system_update_rounded),
                      label: Text(isIos ? 'App Store\'a git' : 'Google Play\'e git'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
