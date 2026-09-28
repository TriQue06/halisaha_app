import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Açılış ekranı + uygulama hazırlığı.
///
/// Sistem açılış ekranı (Android/iOS) düz yeşil; Flutter'ın ilk karesi de
/// aynı yeşille başladığı için geçiş görünmüyor. Ardından logo ve
/// "Japon Kale" yazısı aşağıdan ortaya kayarak ve belirerek geliyor.
///
/// [initialize] (Supabase vb.) animasyonla **paralel** çalışır: animasyon
/// bekleme süresini uzatmaz, zaten beklenen süreyi doldurur. Hem
/// hazırlık hem en kısa gösterim süresi bitince [child]'a hızlıca geçilir.
///
/// Telefonda "hareketi azalt" açıksa kayma yapılmaz, bekleme de eklenmez.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    required this.initialize,
    required this.child,
  });

  /// Uygulama başlamadan önce tamamlanması gereken hazırlık.
  final Future<void> Function() initialize;

  /// Hazırlık bitince gösterilecek ekran.
  final Widget child;

  /// Logo ve yazının kayarak gelme süresi.
  static const Duration introDuration = Duration(milliseconds: 450);

  /// Animasyon bittikten sonra logonun kısa bir an durduğu süre;
  /// hiç durmadan geçilirse göz animasyonu yakalayamıyor.
  static const Duration holdDuration = Duration(milliseconds: 150);

  /// Açılış ekranından uygulamaya geçiş (çapraz solma) süresi.
  static const Duration exitDuration = Duration(milliseconds: 220);

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: AppBootstrap.introDuration,
  );

  late final Animation<double> _fade =
      CurvedAnimation(parent: _intro, curve: Curves.easeOut);

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.35),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));

  bool _started = false;
  bool _ready = false;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery ancak burada okunabildiği için başlatma initState'te değil.
    if (_started) return;
    _started = true;
    _run();
  }

  Future<void> _run() async {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;

    Future<void> minimumShow;
    if (reduceMotion) {
      _intro.value = 1;
      minimumShow = Future<void>.value();
    } else {
      minimumShow = Future.wait<void>(<Future<void>>[
        _intro.forward().orCancel.catchError((Object _) {}),
        Future<void>.delayed(AppBootstrap.introDuration + AppBootstrap.holdDuration),
      ]);
    }

    try {
      await Future.wait<void>(<Future<void>>[widget.initialize(), minimumShow]);
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _run();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppBootstrap.exitDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _ready
          ? KeyedSubtree(key: const ValueKey<String>('app'), child: widget.child)
          : _SplashView(
              key: const ValueKey<String>('splash'),
              fade: _fade,
              slide: _slide,
              error: _error,
              onRetry: _retry,
            ),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView({
    super.key,
    required this.fade,
    required this.slide,
    required this.error,
    required this.onRetry,
  });

  final Animation<double> fade;
  final Animation<Offset> slide;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Yeşil zemin üzerinde durum çubuğu ikonları beyaz.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primaryGreen,
        body: Stack(
          children: <Widget>[
            Center(
              child: Semantics(
                label: 'Japon Kale açılıyor',
                child: FadeTransition(
                  opacity: fade,
                  child: SlideTransition(
                    position: slide,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Görselde top, kenarlarda boşlukla çiziliyor;
                        // 180 px'lik kutuda top yaklaşık 95 px görünüyor.
                        Image.asset(
                          'assets/icon/app_icon_foreground.png',
                          width: 180,
                          height: 180,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                        Transform.translate(
                          // Görselin alt boşluğunu kapatıp yazıyı topa yaklaştır.
                          offset: const Offset(0, -30),
                          child: Text(
                            'Japon Kale',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (error != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 48,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Uygulama başlatılamadı. İnternet bağlantını kontrol et.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: onRetry,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
