import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/match_errors.dart';
import '../../../models/models.dart';
import '../../../state/team_providers.dart';

/// Maç detayında sonucun onay durumu.
///
/// * Onay bekliyor + sonucu onaylayacak kaptan bizsek: "Onayla / İtiraz et".
/// * Onay bekliyor + skoru biz girdiysek: rakibin onayı bekleniyor bilgisi.
/// * İtiraz edildiyse: maçın istatistiklere sayılmadığı bilgisi.
/// * Onaylı sonuçta hiçbir şey göstermez.
class ResultConfirmationCard extends ConsumerStatefulWidget {
  const ResultConfirmationCard({super.key, required this.detail, required this.userId});

  final MatchDetail detail;
  final String? userId;

  @override
  ConsumerState<ResultConfirmationCard> createState() => _ResultConfirmationCardState();
}

class _ResultConfirmationCardState extends ConsumerState<ResultConfirmationCard> {
  bool _busy = false;

  MatchDetail get d => widget.detail;

  Future<void> _respond({required bool accept}) async {
    String? reason;
    if (accept) {
      final bool ok = await _confirmAccept();
      if (!ok) return;
    } else {
      final String? r = await showDialog<String>(
        context: context,
        builder: (_) => const _DisputeDialog(),
      );
      if (r == null) return; // vazgeçti
      reason = r.trim().isEmpty ? null : r.trim();
    }

    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(teamActionsProvider)
          .respondToResult(matchId: d.id, accept: accept, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Sonuç onaylandı, istatistikler güncellendi.'
              : 'İtirazın kaydedildi. Bu maç istatistiklere sayılmayacak.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(turkishMatchError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmAccept() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sonucu onayla'),
        content: Text(
          '${_scoreText()} sonucunu onaylıyor musun? Onaydan sonra sonuç '
          'değiştirilemez ve iki takımın istatistiklerine işlenir.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Onayla')),
        ],
      ),
    );
    return ok ?? false;
  }

  String _scoreText() {
    final int? a = d.challenger.score;
    final int? b = d.opponent.score;
    if (a == null || b == null) return 'Girilen';
    return '${d.challenger.teamName} $a - $b ${d.opponent.teamName}';
  }

  static String _left(Duration? left) {
    if (left == null) return '48 saat';
    if (left.inHours >= 1) return '${left.inHours} saat';
    if (left.inMinutes >= 1) return '${left.inMinutes} dakika';
    return 'birkaç dakika';
  }

  @override
  Widget build(BuildContext context) {
    if (d.status != MatchStatus.completed || d.resultStatus == ResultStatus.confirmed) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final String? me = widget.userId;

    // --- İtiraz edildi -------------------------------------------------
    if (d.resultStatus == ResultStatus.disputed) {
      final bool involved = d.sideOf(me) != null;
      final String? reason = d.disputeReason;
      return _Banner(
        color: AppColors.loss,
        icon: Icons.gavel_rounded,
        title: 'Sonuca itiraz edildi',
        message: <String>[
          '${d.confirmingSide.teamName} bu sonuca itiraz etti. Maç, iki takımın '
              'istatistiklerine sayılmadı.',
          if (involved && reason != null && reason.isNotEmpty) 'Not: "$reason"',
        ].join('\n'),
      );
    }

    // --- Onay bekliyor: yanıt verecek taraf biziz ---------------------
    if (d.canRespondToResult(me)) {
      return _Banner(
        color: AppColors.info,
        icon: Icons.fact_check_outlined,
        title: 'Sonuç doğru mu?',
        message: '${d.reportingSide.teamName} skoru girdi. Doğruysa onayla, '
            'yanlışsa itiraz et. ${_left(d.timeLeftToRespond)} içinde yanıt '
            'vermezsen sonuç otomatik onaylanır.',
        actions: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _respond(accept: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.loss,
                  side: BorderSide(color: AppColors.loss.withValues(alpha: 0.6)),
                ),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('İtiraz et'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _respond(accept: true),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('Onayla'),
              ),
            ),
          ],
        ),
      );
    }

    // --- Onay bekliyor: skoru biz girdik ya da maçın tarafı değiliz ----
    final bool iReported = me != null && d.reportingSide.captainId == me;
    return _Banner(
      color: AppColors.draw,
      icon: Icons.hourglass_top_rounded,
      title: 'Onay bekliyor',
      message: iReported
          ? '${d.confirmingSide.teamName} takımının onayı bekleniyor. '
              '${_left(d.timeLeftToRespond)} içinde yanıt gelmezse sonuç otomatik '
              'onaylanır; onaylanınca istatistiklere işlenir.'
          : 'Bu sonuç ${d.confirmingSide.teamName} takımının onayını bekliyor.',
      textStyle: theme.textTheme.bodySmall,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    this.actions,
    this.textStyle,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final Widget? actions;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: textStyle ?? theme.textTheme.bodyMedium),
          if (actions != null) ...<Widget>[
            const SizedBox(height: 12),
            actions!,
          ],
        ],
      ),
    );
  }
}

/// İtiraz onayı + isteğe bağlı kısa not. Vazgeçilirse null, itirazda
/// (boş olabilir) not döner.
class _DisputeDialog extends StatefulWidget {
  const _DisputeDialog();

  @override
  State<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<_DisputeDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sonuca itiraz et'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'İtiraz edilen maç iki takımın istatistiklerine de sayılmaz. '
            'Bu işlem geri alınamaz.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 300,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Not (isteğe bağlı)',
              hintText: 'Örn. Maç 3-2 bitti',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
          onPressed: () => Navigator.pop(context, _note.text),
          child: const Text('İtiraz et'),
        ),
      ],
    );
  }
}
