import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import 'pitch_detail_screen.dart';

/// Halı Sahalar sekmesi — arama çubuğu + kompakt dikey liste (fikstür görünümü).
class PitchesScreen extends ConsumerWidget {
  const PitchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Pitch> pitches = ref.watch(filteredPitchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halı Sahalar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _PitchSearchField(
              onChanged: (String value) =>
                  ref.read(pitchSearchQueryProvider.notifier).state = value,
            ),
          ),
        ),
      ),
      body: pitches.isEmpty
          ? const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Saha bulunamadı',
              message: 'Farklı bir isim veya ilçe ile aramayı deneyin.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: pitches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) =>
                  _PitchListTile(pitch: pitches[index]),
            ),
    );
  }
}

class _PitchSearchField extends StatelessWidget {
  const _PitchSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: 'Saha veya ilçe ara...',
        prefixIcon: Icon(Icons.search_rounded),
        isDense: true,
      ),
    );
  }
}

/// Maçkolik tarzı kompakt saha satırı.
class _PitchListTile extends ConsumerWidget {
  const _PitchListTile({required this.pitch});

  final Pitch pitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    // Kullanıcının bu sahada takımı varsa satırda küçük bir rozet gösterilir.
    final Team? myTeam = ref.watch(myTeamForPitchProvider(pitch.id));

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PitchDetailScreen(pitchId: pitch.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: const PitchImagePlaceholder(width: 62, height: 62, iconSize: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            pitch.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (myTeam != null) ...<Widget>[
                          const SizedBox(width: 6),
                          const InfoPill(label: 'Takımım', icon: Icons.shield_rounded),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${pitch.district} · ${pitch.address}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        InfoPill(
                          label: '${pitch.teamCount} takım',
                          icon: Icons.groups_rounded,
                        ),
                        const SizedBox(width: 6),
                        InfoPill(
                          label: pitch.isIndoor ? 'Kapalı' : 'Açık',
                          icon: pitch.isIndoor
                              ? Icons.roofing_rounded
                              : Icons.wb_sunny_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const Spacer(),
                        if (pitch.pricePerHour != null)
                          Text(
                            '${pitch.pricePerHour!.toStringAsFixed(0)} ₺/saat',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
