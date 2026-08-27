import 'package:flutter/material.dart';

import '../goalkeepers/goalkeepers_screen.dart';
import '../home/home_screen.dart';
import '../pitches/pitches_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

/// Uygulamanın ana iskeleti: 5 sekmeli alt navigasyon.
///
/// Sekmeler [IndexedStack] içinde tutulur; böylece sekme değiştirildiğinde
/// scroll pozisyonu ve form state'i korunur.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

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

  void _onTap(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: _onTap,
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
