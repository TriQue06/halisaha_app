import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/moderation_repository.dart';
import '../../state/app_providers.dart';
import '../../state/moderation_providers.dart';

/// Kaleci kartı, takım satırı ve maç kartındaki "⋮" menüsü:
/// **Rapor et** ve **Engelle**.
///
/// Kullanıcının kendi içeriğinde hiç görünmez.
class ModerationMenuButton extends ConsumerWidget {
  const ModerationMenuButton({
    super.key,
    required this.userId,
    required this.displayName,
    required this.reportContext,
    this.matchId,
    this.iconSize = 20,
  });

  /// Raporlanacak/engellenecek kullanıcı (takımlarda kaptan).
  final String userId;

  /// Diyaloglarda gösterilecek ad (kişi ya da takım adı).
  final String displayName;
  final ReportContext reportContext;
  final String? matchId;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? me = ref.watch(currentUserIdProvider);
    if (userId.isEmpty || userId == me) return const SizedBox.shrink();

    return PopupMenuButton<_MenuAction>(
      tooltip: 'Diğer seçenekler',
      icon: Icon(Icons.more_vert_rounded, size: iconSize),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 180),
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelected: (_MenuAction action) {
        switch (action) {
          case _MenuAction.report:
            showReportSheet(
              context,
              ref,
              userId: userId,
              displayName: displayName,
              reportContext: reportContext,
              matchId: matchId,
            );
          case _MenuAction.block:
            confirmBlock(context, ref,
                userId: userId, displayName: displayName);
        }
      },
      itemBuilder: (BuildContext context) =>
          const <PopupMenuEntry<_MenuAction>>[
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.report,
          child: ListTile(
            leading: Icon(Icons.flag_outlined),
            title: Text('Rapor et'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.block,
          child: ListTile(
            leading: Icon(Icons.block_rounded, color: AppColors.loss),
            title: Text('Engelle', style: TextStyle(color: AppColors.loss)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }
}

enum _MenuAction { report, block }

/// Rapor penceresini açar. Rapor gönderilirse ardından engelleme önerilir.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String displayName,
  required ReportContext reportContext,
  String? matchId,
}) async {
  final bool? sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => _ReportSheet(
      userId: userId,
      displayName: displayName,
      reportContext: reportContext,
      matchId: matchId,
    ),
  );
  if (sent != true || !context.mounted) return;

  final bool? block = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle_outline_rounded),
      title: const Text('Raporun alındı'),
      content: Text(
        'En geç 24 saat içinde inceleyeceğiz.\n\n'
        '$displayName kullanıcısını engellemek ister misin? Engellersen '
        'kaleci profilini ve takımlarını bir daha görmezsin, birbirinize maç '
        'teklifi gönderemezsiniz.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Hayır'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
          child: const Text('Engelle'),
        ),
      ],
    ),
  );
  if (block == true && context.mounted) {
    await _block(context, ref, userId: userId, displayName: displayName);
  }
}

/// Doğrudan engelleme (menüden): önce neler olacağını anlatıp onay alır.
Future<void> confirmBlock(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String displayName,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text('$displayName engellensin mi?'),
      content: const Text(
        '• Kaleci profili ve takımları sana görünmez, sen de ona görünmezsin.\n'
        '• Birbirinize maç teklifi gönderemezsiniz.\n'
        '• Aranızda devam eden maçlar iptal edilir.\n\n'
        'Engeli istediğin zaman Ayarlar → Engellenen kullanıcılar\'dan '
        'kaldırabilirsin.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
          child: const Text('Engelle'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await _block(context, ref, userId: userId, displayName: displayName);
  }
}

Future<void> _block(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String displayName,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final int cancelled =
        await ref.read(moderationActionsProvider).block(userId);
    messenger.showSnackBar(SnackBar(
      content: Text(cancelled > 0
          ? '$displayName engellendi. Aranızdaki $cancelled maç iptal edildi.'
          : '$displayName engellendi.'),
    ));
  } catch (error) {
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Engellenemedi. İnternet bağlantını kontrol et.')),
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.userId,
    required this.displayName,
    required this.reportContext,
    this.matchId,
  });

  final String userId;
  final String displayName;
  final ReportContext reportContext;
  final String? matchId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final TextEditingController _description = TextEditingController();
  ReportReason? _reason;
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_isBusy &&
      _reason != null &&
      (!_reason!.requiresDescription || _description.text.trim().isNotEmpty);

  Future<void> _submit() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await ref.read(moderationActionsProvider).report(
            reportedUserId: widget.userId,
            context: widget.reportContext,
            reason: _reason!,
            description: _description.text,
            matchId: widget.matchId,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on DuplicateReportException {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = 'Bu kullanıcıyı zaten raporladın; raporun inceleniyor.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error =
            'Rapor gönderilemedi. İnternet bağlantını kontrol edip tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Rapor et',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.displayName} ile ilgili sorun ne? Raporun karşı tarafa '
              'gösterilmez.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (ReportReason? v) {
                if (_isBusy) return;
                setState(() => _reason = v);
              },
              child: Column(
                children: <Widget>[
                  for (final ReportReason reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: reason,
                      title: Text(reason.label),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _description,
              enabled: !_isBusy,
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _reason?.requiresDescription ?? false
                    ? 'Ne oldu? (zorunlu)'
                    : 'Eklemek istediğin bir şey var mı? (isteğe bağlı)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _error!,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: AppColors.loss),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: _isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Raporu gönder'),
            ),
          ],
        ),
      ),
    );
  }
}
