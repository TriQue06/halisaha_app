import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import 'widgets/district_picker.dart';
import 'widgets/goalkeeper_card.dart';

/// Kaleci Arama sekmesi.
///
/// Üstte tam genişlikte "İlçe Seçiniz..." butonu, altında kaleci kartları.
class GoalkeepersScreen extends ConsumerWidget {
  const GoalkeepersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? selectedDistrict = ref.watch(selectedDistrictProvider);
    final List<Goalkeeper> goalkeepers = ref.watch(filteredGoalkeepersProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kaleciler')),
      body: Column(
        children: <Widget>[
          // --- İlçe filtresi -------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: DistrictSelectorButton(
              selectedDistrict: selectedDistrict,
              onChanged: (String? district) =>
                  ref.read(selectedDistrictProvider.notifier).state = district,
            ),
          ),

          // --- Sonuç sayısı --------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Row(
              children: <Widget>[
                Text(
                  selectedDistrict == null
                      ? 'Tüm İzmir'
                      : '$selectedDistrict bölgesinde oynayanlar',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${goalkeepers.length} kaleci',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // --- Kaleci listesi ------------------------------------------
          Expanded(
            child: goalkeepers.isEmpty
                ? EmptyState(
                    icon: Icons.sports_mma_outlined,
                    title: 'Bu ilçede kaleci bulunamadı',
                    message: 'Farklı bir ilçe seçebilir veya filtreyi kaldırabilirsiniz.',
                    action: OutlinedButton(
                      onPressed: () =>
                          ref.read(selectedDistrictProvider.notifier).state = null,
                      child: const Text('Filtreyi Temizle'),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: goalkeepers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final Goalkeeper goalkeeper = goalkeepers[index];
                      return GoalkeeperCard(
                        goalkeeper: goalkeeper,
                        onContact: () => _showContactSheet(context, goalkeeper),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// İletişim bilgisi ve puan verme aksiyonlarını içeren alt sayfa.
  void _showContactSheet(BuildContext context, Goalkeeper goalkeeper) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  goalkeeper.fullName,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                RatingStars(rating: goalkeeper.rating, ratingCount: goalkeeper.ratingCount),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_rounded),
                  title: Text(goalkeeper.phone),
                  subtitle: const Text('Telefon numarası'),
                  trailing: FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${goalkeeper.phone} aranıyor...')),
                      );
                    },
                    child: const Text('Ara'),
                  ),
                ),
                const Divider(height: 24),
                Text(
                  'Bu kaleciyle oynadıysanız puan verebilirsiniz.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    for (int star = 1; star <= 5; star++)
                      IconButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${goalkeeper.fullName} için $star puan verildi.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.star_rounded, size: 30),
                        color: theme.colorScheme.onSurfaceVariant,
                        tooltip: '$star puan',
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
