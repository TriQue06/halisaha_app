import 'package:flutter/material.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';

/// Kaleci kartı.
///
/// İçerik: profil fotoğrafı (yoksa varsayılan ikon), yaş, oynayabildiği
/// ilçeler, 5 üzerinden yıldızlı puan, "Hakkımda" metni ve iletişim butonu.
class GoalkeeperCard extends StatelessWidget {
  const GoalkeeperCard({
    super.key,
    required this.goalkeeper,
    required this.onContact,
  });

  final Goalkeeper goalkeeper;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _GoalkeeperAvatar(goalkeeper: goalkeeper),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              goalkeeper.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· ${goalkeeper.age}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      RatingStars(
                        rating: goalkeeper.rating,
                        ratingCount: goalkeeper.ratingCount,
                      ),
                    ],
                  ),
                ),
                if (goalkeeper.isAvailable)
                  const InfoPill(label: 'Müsait', icon: Icons.circle, color: Color(0xFF17A45C)),
              ],
            ),
            const SizedBox(height: 12),

            // --- Oynayabildiği ilçeler --------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final String district in goalkeeper.districts)
                        InfoPill(
                          label: district,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // --- Hakkımda --------------------------------------------
            Text(
              goalkeeper.about,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),

            // --- İletişim --------------------------------------------
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('İletişime Geç'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onContact,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.star_outline_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Profil fotoğrafı varsa CircleAvatar içinde gösterilir, yoksa varsayılan ikon.
class _GoalkeeperAvatar extends StatelessWidget {
  const _GoalkeeperAvatar({required this.goalkeeper});

  final Goalkeeper goalkeeper;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? url = goalkeeper.avatarUrl;

    return CircleAvatar(
      radius: 27,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      foregroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
      // foregroundImage yüklenemezse/yoksa child görünür.
      child: Icon(
        Icons.sports_mma_rounded,
        size: 26,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
