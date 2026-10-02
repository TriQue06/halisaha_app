import 'package:flutter/material.dart';

import '../../../models/models.dart';

/// "Bu maç kaç kişilik olacak?" — 5v5 ile 11v11 arası seçim.
///
/// [hasLineup] doluysa kişi sayısı değişince seçilmiş kadroların
/// sıfırlanacağı hatırlatılır.
Future<int?> showTeamSizePicker(
  BuildContext context, {
  int? initial,
  bool hasLineup = false,
}) {
  int selected = initial ?? 7;

  return showDialog<int>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: const Text('Bu maç kaç kişilik olacak?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Takım başına oyuncu sayısı (kaleci dahil).'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (int n = kMinTeamSize; n <= kMaxTeamSize; n++)
                  ChoiceChip(
                    label: Text('${n}v$n'),
                    selected: selected == n,
                    onSelected: (_) => setState(() => selected = n),
                  ),
              ],
            ),
            if (hasLineup && initial != null && selected != initial) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Kişi sayısı değişirse iki takımın seçtiği maç kadroları sıfırlanır.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(selected),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
}
