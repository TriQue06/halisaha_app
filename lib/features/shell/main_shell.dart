import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/services/push_service.dart';
import '../../state/app_providers.dart';
import '../goalkeepers/goalkeepers_screen.dart';
import '../home/home_screen.dart';
import '../pitches/pitches_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

/// Alt navigasyonda seçili sekme.
///
/// Riverpod'a taşındı: bildirim ekranı gibi başka yerlerden programatik
/// olarak sekme değiştirmek gerekiyor (ör. maç bildirimine dokununca
/// "Profilim" sekmesine gitmek).
final StateProvider<int> selectedTabProvider = StateProvider<int>((Ref ref) => 0);

/// Sekme sırasını sabit isimlerle anlatır; index sihirli sayı olmasın.
enum MainTab { home, pitches, goalkeepers, profile, settings }

/// Uygulamanın ana iskeleti: 5 sekmeli alt navigasyon.
///
/// Sekmeler [IndexedStack] içinde tutulur; böylece sekme değiştirildiğinde
/// scroll pozisyonu ve form state'i korunur.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  /// Her sekme kendi Navigator'ına sahip olsun istenirse burada
  /// `Navigator` sarmalayıcıları eklenebilir. Şimdilik tek Navigator yeterli.
  static const List<Widget> _tabs = <Widget>[
    HomeScreen(),
    PitchesScreen(),
    GoalkeepersScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

  static const List<_TabSpec> _specs = <_TabSpec>[
    _TabSpec(label: 'Ana Sayfa', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    _TabSpec(label: 'Sahalar', icon: Icons.stadium_outlined, activeIcon: Icons.stadium_rounded),
    _TabSpec(
      label: 'Kaleciler',
      icon: Icons.sports_mma_outlined, // eldiven
      activeIcon: Icons.sports_mma_rounded,
    ),
    _TabSpec(label: 'Profilim', icon: Icons.person_outline, activeIcon: Icons.person_rounded),
    _TabSpec(label: 'Ayarlar', icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(selectedTabProvider);

    // Push bildirimine dokunulduğunda maç akışının yaşadığı sekmeye geç ve
    // bildirim listesini tazele. PushService Riverpod dışında (statik) olduğu
    // için köprüyü burada kuruyoruz.
    PushService.onNotificationTap = () {
      ref.read(selectedTabProvider.notifier).state = MainTab.profile.index;
      ref.invalidate(notificationsProvider);
      ref.invalidate(pendingMatchesProvider);
    };

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
