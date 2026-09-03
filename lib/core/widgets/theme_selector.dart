import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_controller.dart';

/// Üç seçenekli tema seçici: Cihaz / Açık / Koyu.
///
/// Varsayılan **Cihaz**: uygulama sistemin açık-koyu ayarını izler.
/// Hem Ayarlar sekmesinde hem giriş/kayıt ekranlarında aynı bileşen
/// kullanılıyor ki seçim her yerde aynı davransın.
class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key, this.compact = false});

  /// Giriş ekranlarında başlık/açıklama olmadan yalnızca düğmeler gösterilir.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ThemeMode mode = ref.watch(settingsProvider).themeMode;
    final SettingsController controller = ref.read(settingsProvider.notifier);

    // Kompakt modda yalnızca ikon: giriş ekranının başlık satırında
    // etiketli hâli dar telefonlarda taşıyor.
    final Widget buttons = SegmentedButton<ThemeMode>(
      segments: <ButtonSegment<ThemeMode>>[
        ButtonSegment<ThemeMode>(
          value: ThemeMode.system,
          icon: const Icon(Icons.phone_android_rounded, size: 17),
          label: compact ? null : const Text('Cihaz'),
          tooltip: 'Cihaz ayarı',
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.light,
          icon: const Icon(Icons.light_mode_rounded, size: 17),
          label: compact ? null : const Text('Açık'),
          tooltip: 'Açık tema',
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.dark,
          icon: const Icon(Icons.dark_mode_rounded, size: 17),
          label: compact ? null : const Text('Koyu'),
          tooltip: 'Koyu tema',
        ),
      ],
      selected: <ThemeMode>{mode},
      showSelectedIcon: false,
      onSelectionChanged: (Set<ThemeMode> selection) =>
          controller.setThemeMode(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll<TextStyle>(
          theme.textTheme.labelMedium ?? const TextStyle(fontSize: 12),
        ),
        // Yeşil başlık üzerinde okunur kalsın.
        foregroundColor: compact
            ? WidgetStatePropertyAll<Color>(Colors.white.withValues(alpha: 0.9))
            : null,
        side: compact
            ? WidgetStatePropertyAll<BorderSide>(
                BorderSide(color: Colors.white.withValues(alpha: 0.45)),
              )
            : null,
        backgroundColor: compact
            ? WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) => states.contains(WidgetState.selected)
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.transparent,
              )
            : null,
      ),
    );

    if (compact) return buttons;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                switch (mode) {
                  ThemeMode.light => Icons.light_mode_rounded,
                  ThemeMode.dark => Icons.dark_mode_rounded,
                  ThemeMode.system => Icons.phone_android_rounded,
                },
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Tema', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      switch (mode) {
                        ThemeMode.light => 'Koyu yeşil & beyaz tema',
                        ThemeMode.dark => 'Koyu yeşil & siyah tema',
                        ThemeMode.system => 'Cihazın ayarını izliyor',
                      },
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: buttons),
        ],
      ),
    );
  }
}
