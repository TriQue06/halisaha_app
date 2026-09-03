import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/phone_launcher.dart';
import '../../core/widgets/banner_ad_slot.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import 'widgets/district_picker.dart';
import 'widgets/goalkeeper_card.dart';

/// Kaleci Arama sekmesi.
///
/// Liste Supabase'deki `goalkeeper_profiles` view'ından gelir; ilçe filtresi
/// veritabanı tarafında uygulanır. Aşağı çekerek yenilenebilir.
class GoalkeepersScreen extends ConsumerWidget {
  const GoalkeepersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? selectedDistrict = ref.watch(selectedDistrictProvider);
    final AsyncValue<List<Goalkeeper>> goalkeepers = ref.watch(goalkeepersProvider);
    final ThemeData theme = Theme.of(context);

    Future<void> refresh() async {
      ref.invalidate(goalkeepersProvider);
      await ref.read(goalkeepersProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaleciler'),
        actions: <Widget>[
          IconButton(
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
          ),
        ],
      ),
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
                goalkeepers.when(
                  loading: () => const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (List<Goalkeeper> list) => Text(
                    '${list.length} kaleci',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Kaleci listesi ------------------------------------------
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: goalkeepers.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stack) => _ErrorView(
                  message: error.toString(),
                  onRetry: refresh,
                ),
                data: (List<Goalkeeper> list) {
                  if (list.isEmpty) {
                    // AlwaysScrollable: liste boşken de aşağı çekilebilsin.
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: <Widget>[
                        const SizedBox(height: 40),
                        EmptyState(
                          icon: Icons.sports_mma_outlined,
                          title: selectedDistrict == null
                              ? 'Henüz kayıtlı kaleci yok'
                              : '$selectedDistrict için kaleci bulunamadı',
                          message: selectedDistrict == null
                              ? 'İlk kaleci sen ol: Profilim → Kaleci Profilim.'
                              : 'Farklı bir ilçe seçebilir veya filtreyi kaldırabilirsin.',
                          action: selectedDistrict == null
                              ? null
                              : OutlinedButton(
                                  onPressed: () => ref
                                      .read(selectedDistrictProvider.notifier)
                                      .state = null,
                                  child: const Text('Filtreyi Temizle'),
                                ),
                        ),
                      ],
                    );
                  }

                  // Reklam listenin SONUNA konuyor, kartların arasına
                  // değil: kartların altında "İletişime Geç" butonu var ve
                  // AdMob tıklanabilir öğeye bitişik reklamı yasaklıyor.
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == list.length) {
                        return const BannerAdSlot(
                          padding: EdgeInsets.only(top: 6),
                        );
                      }
                      final Goalkeeper goalkeeper = list[index];
                      return GoalkeeperCard(
                        goalkeeper: goalkeeper,
                        onContact: () => _showContactSheet(context, ref, goalkeeper),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// İletişim bilgisi ve puan verme aksiyonlarını içeren alt sayfa.
  void _showContactSheet(BuildContext context, WidgetRef ref, Goalkeeper goalkeeper) {
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
                  trailing: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      PhoneLauncher.call(context, goalkeeper.phone);
                    },
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: const Text('Ara'),
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
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final ScaffoldMessengerState messenger =
                              ScaffoldMessenger.of(context);
                          try {
                            await ref.read(repositoryProvider).rateGoalkeeper(
                                  goalkeeperId: goalkeeper.id,
                                  rating: star,
                                );
                            ref.invalidate(goalkeepersProvider);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${goalkeeper.fullName} için $star puan verildi.',
                                ),
                              ),
                            );
                          } catch (error) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Puan verilemedi: $error')),
                            );
                          }
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

/// Veri çekilemediğinde gösterilen, yeniden denenebilir hata görünümü.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 40),
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Kaleciler yüklenemedi',
          message: message,
          action: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tekrar Dene'),
          ),
        ),
      ],
    );
  }
}
