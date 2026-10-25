import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/push_service.dart';
import '../../state/app_providers.dart';
import '../goalkeepers/goalkeepers_screen.dart';
import '../home/home_screen.dart';
import '../matches/matches_screen.dart';
import '../pitches/pitches_screen.dart';
import '../profile/profile_screen.dart';
import '../teams/match_detail_screen.dart';

/// Alt navigasyonda seçili sekme.
///
/// Riverpod'a taşındı: bildirim ekranı gibi başka yerlerden programatik
/// olarak sekme değiştirmek gerekiyor (ör. maç bildirimine dokununca
/// "Profilim" sekmesine gitmek).
final StateProvider<int> selectedTabProvider = StateProvider<int>((Ref ref) => 0);

/// Sekme sırasını sabit isimlerle anlatır; index sihirli sayı olmasın.
///
/// Maçlar, uygulamanın asıl işi olduğu için kendi sekmesinde; Ayarlar
/// profilin sağ üstündeki dişliden açılıyor.
enum MainTab { home, pitches, matches, goalkeepers, profile }

/// Uygulamanın ana iskeleti: 5 sekmeli alt navigasyon.
///
/// Sekmeler [IndexedStack] içinde tutulur; böylece sekme değiştirildiğinde
/// scroll pozisyonu ve form state'i korunur.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // Push bildirimine dokunulunca ilgili maça git. PushService Riverpod
    // dışında (statik) olduğu için köprüyü burada kuruyoruz; uygulama
    // kapalıyken dokunulan bildirim de burada işlenir.
    PushService.onNotificationTap = _openFromNotification;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushService.consumePendingTap();
    });
  }

  @override
  void dispose() {
    if (PushService.onNotificationTap == _openFromNotification) {
      PushService.onNotificationTap = null;
    }
    super.dispose();
  }

  void _openFromNotification(NotificationTap tap) {
    if (!mounted) return;
    ref.invalidate(notificationsProvider);
    ref.invalidate(pendingMatchesProvider);
    ref.invalidate(matchHistoryProvider);
    ref.read(selectedTabProvider.notifier).state = MainTab.matches.index;

    // Sonuçlanmış maç bildirimi doğrudan maç detayını açar; diğerleri
    // (teklif, onay, tarih) Maçlar sekmesindeki kartta aksiyon bekler.
    final String? matchId = tap.matchId;
    if (matchId != null && matchId.isNotEmpty && tap.type == 'match_completed') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => MatchDetailScreen(matchId: matchId)),
      );
    }
  }

  /// Her sekme kendi Navigator'ına sahip olsun istenirse burada
  /// `Navigator` sarmalayıcıları eklenebilir. Şimdilik tek Navigator yeterli.
  static const List<Widget> _tabs = <Widget>[
    HomeScreen(),
    PitchesScreen(),
    MatchesScreen(),
    GoalkeepersScreen(),
    ProfileScreen(),
  ];

  static const List<_TabSpec> _specs = <_TabSpec>[
    _TabSpec(label: 'Ana Sayfa', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    _TabSpec(label: 'Sahalar', icon: Icons.stadium_outlined, activeIcon: Icons.stadium_rounded),
    _TabSpec(
      label: 'Maçlar',
      icon: Icons.sports_soccer_outlined,
      activeIcon: Icons.sports_soccer_rounded,
    ),
    _TabSpec(
      label: 'Kaleciler',
      icon: Icons.sports_mma_outlined, // eldiven
      activeIcon: Icons.sports_mma_rounded,
    ),
    _TabSpec(label: 'Profil', icon: Icons.person_outline, activeIcon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final int index = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline)),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (int next) => ref.read(selectedTabProvider.notifier).state = next,
          items: <BottomNavigationBarItem>[
            for (final _TabSpec spec in _specs)
              BottomNavigationBarItem(
                icon: Icon(spec.icon),
                activeIcon: Icon(spec.activeIcon),
                label: spec.label,
                tooltip: spec.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
