import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/match_errors.dart';
import '../../../core/utils/phone_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../data/moderation_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';
import '../../moderation/report_action_sheet.dart';
import '../../teams/lineup_picker_screen.dart';
import '../../teams/match_result_screen.dart';
import '../../teams/widgets/team_size_picker.dart';

/// "Bekleyen Maçlar" kartı — 4 aşamalı onay sisteminin tüm UI state'i.
///
/// Kart hangi aksiyonu göstereceğine [PendingMatch.stage] üzerinden karar verir:
///
/// | Aşama                | Görünen aksiyon                          | İletişim |
/// |----------------------|------------------------------------------|----------|
/// | invitationReceived   | Kabul Et / Reddet                        | gizli    |
/// | invitationSent       | "Yanıt bekleniyor" + Geri Çek            | gizli    |
/// | readinessPending     | "Maça Hazırım" + 1 haftalık geri sayım   | gizli    |
/// | confirmed            | Tarih belirle / maç detayı               | AÇIK     |
/// | awaitingResult       | Kazandık / Berabere / Kaybettik          | AÇIK     |
/// | expired              | Otomatik iptal bilgisi                   | gizli    |
class PendingMatchCard extends ConsumerWidget {
  const PendingMatchCard({super.key, required this.match});

  final PendingMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Süreye bağlı aşamalar (geri sayım, sonuç eşiği) dakikada bir tazelenir.
    ref.watch(minuteTickProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CardHeader(match: match),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // AŞAMA 3 & 4: İletişim bilgileri yalnızca iki taraf da
            // "Maça Hazırım" dedikten sonra açılır.
            if (match.isContactVisible) ...<Widget>[
              _ContactPanel(match: match),
              const SizedBox(height: 12),
            ],

            // Aşamaya özel aksiyon alanı
            _StageActions(match: match),

            // Kabul edilmiş maçtan çıkış yolu (önceden yalnızca sunucuda vardı).
            if (match.canCancel && match.stage != PendingMatchStage.expired)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _confirmCancel(context, ref, match),
                  icon: const Icon(Icons.event_busy_rounded, size: 18),
                  label: Text(
                    match.stage == PendingMatchStage.awaitingResult
                        ? 'Maç oynanmadı'
                        : 'Maçı iptal et',
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.loss),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// İptal onayı; sebep rakibe bildirimde gösterilir.
Future<void> _confirmCancel(BuildContext context, WidgetRef ref, PendingMatch match) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final TextEditingController reason = TextEditingController();

  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Maçı iptal et'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${match.opponentTeamName} ile maç iptal edilecek ve rakibe bildirilecek.'),
          const SizedBox(height: 12),
          TextField(
            controller: reason,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Sebep (isteğe bağlı)'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('İptal Et'),
        ),
      ],
    ),
  );
  final String text = reason.text.trim();
  reason.dispose();
  if (ok != true) return;

  try {
    await ref.read(matchActionsProvider).cancel(
          match.id,
          reason: text.isEmpty ? 'Maç iptal edildi' : text,
        );
    messenger.showSnackBar(const SnackBar(content: Text('Maç iptal edildi.')));
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(turkishMatchError(error))));
  }
}

// =====================================================================
// Başlık: takımlar, saha, durum rozeti
// =====================================================================
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.match});

  final PendingMatch match;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _StageBadge(stage: match.stage)),
            if (match.isChallenger)
              const InfoPill(label: 'Teklifi siz gönderdiniz', icon: Icons.bolt_rounded),
            ModerationMenuButton(
              userId: match.opponentCaptainId,
              displayName: match.opponentTeamName,
              reportContext: ReportContext.match,
              matchId: match.id,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.shield_rounded, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    match.opponentTeamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${match.myTeamName} · ${match.pitchName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (match.matchDate != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    DateFormat('d MMM', 'tr_TR').format(match.matchDate!),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm').format(match.matchDate!),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Aşamayı anlatan renkli rozet.
class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});

  final PendingMatchStage stage;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color, IconData icon) = switch (stage) {
      PendingMatchStage.invitationReceived => (
          'MAÇ TEKLİFİ',
          AppColors.info,
          Icons.mark_email_unread_rounded,
        ),
      PendingMatchStage.invitationSent => (
          'YANIT BEKLENİYOR',
          AppColors.draw,
          Icons.hourglass_top_rounded,
        ),
      PendingMatchStage.readinessPending => (
          'KARŞILIKLI ONAY BEKLENİYOR',
          AppColors.draw,
          Icons.how_to_reg_outlined,
        ),
      PendingMatchStage.confirmed => (
          'MAÇ KESİNLEŞTİ',
          AppColors.win,
          Icons.verified_rounded,
        ),
      PendingMatchStage.awaitingResult => (
          'SONUÇ BEKLENİYOR',
          AppColors.loss,
          Icons.emoji_events_outlined,
        ),
      PendingMatchStage.expired => (
          'SÜRESİ DOLDU',
          AppColors.loss,
          Icons.cancel_outlined,
        ),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: InfoPill(label: label, icon: icon, color: color),
    );
  }
}

// =====================================================================
// AŞAMA 3: İletişim paneli (yalnızca karşılıklı onay sonrası)
// =====================================================================
class _ContactPanel extends StatelessWidget {
  const _ContactPanel({required this.match});

  final PendingMatch match;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.win.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.win.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.lock_open_rounded, color: AppColors.win, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  match.opponentCaptainName,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  match.opponentPhone,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => PhoneLauncher.call(context, match.opponentPhone),
            icon: const Icon(Icons.phone_rounded, size: 16),
            label: const Text('Ara'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.win,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Aşamaya göre aksiyonlar
// =====================================================================
class _StageActions extends ConsumerWidget {
  const _StageActions({required this.match});

  final PendingMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MatchActions actions = ref.read(matchActionsProvider);

    switch (match.stage) {
      // -----------------------------------------------------------------
      // AŞAMA 1a — Bize teklif geldi: Kabul / Reddet
      // -----------------------------------------------------------------
      case PendingMatchStage.invitationReceived:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _HintText(
              '${match.opponentTeamName} size maç teklifi gönderdi. Kabul ederseniz '
              'iki tarafın da 1 hafta içinde "Maça Hazırım" onayı vermesi gerekir.',
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmReject(context, actions),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.loss),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _run(
                      context,
                      () => actions.accept(match.id),
                      successMessage:
                          'Teklif kabul edildi. Şimdi "Maça Hazırım" onayı verin.',
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Kabul Et'),
                  ),
                ),
              ],
            ),
          ],
        );

      // -----------------------------------------------------------------
      // AŞAMA 1b — Teklifi biz gönderdik: rakibin yanıtını bekliyoruz
      // -----------------------------------------------------------------
      case PendingMatchStage.invitationSent:
        return Row(
          children: <Widget>[
            Expanded(
              child: _HintText(
                '${match.opponentTeamName} takımının yanıtı bekleniyor.',
              ),
            ),
            TextButton(
              onPressed: () => _confirmReject(context, actions, isWithdraw: true),
              child: const Text('Geri Çek'),
            ),
          ],
        );

      // -----------------------------------------------------------------
      // AŞAMA 2 — "Maça Hazırım" (iki taraf da basmalı, süre 1 hafta)
      // -----------------------------------------------------------------
      case PendingMatchStage.readinessPending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ReadinessCountdown(match: match),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ReadyChip(
                    label: 'Siz',
                    isReady: match.myTeamReady,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ReadyChip(
                    label: match.opponentTeamName,
                    isReady: match.opponentReady,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (match.myTeamReady)
              // Onayımızı verdik; rakibin onayı bekleniyor.
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Onayınız alındı · Rakip bekleniyor'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              )
            else
              FilledButton.icon(
                onPressed: () => _run(
                  context,
                  () => actions.markReady(match.id),
                  successMessage: 'Onayınız kaydedildi.',
                ),
                icon: const Icon(Icons.sports_soccer_rounded, size: 18),
                label: const Text('MAÇA HAZIRIM'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
          ],
        );

      // -----------------------------------------------------------------
      // AŞAMA 3 — Maç kesinleşti: tarih belirleme / bekleme
      // -----------------------------------------------------------------
      case PendingMatchStage.confirmed:
        if (match.matchDate == null) {
          // Gün ve saati yalnızca teklifi gönderen takım girer.
          return match.isChallenger
              ? FilledButton.icon(
                  onPressed: () => _pickMatchDate(context, actions),
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: const Text('Maç Gün ve Saatini Belirle'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                )
              : _HintText(
                  'İki taraf da hazır. ${match.opponentTeamName} maç gün ve saatini girecek.',
                );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _HintText(
                    'Maç ${DateFormat("d MMMM EEEE, HH:mm", "tr_TR").format(match.matchDate!)} '
                    'tarihinde ${match.pitchName} sahasında'
                    '${match.teamSize == null ? '' : ' · ${match.teamSize}v${match.teamSize}'}.',
                  ),
                ),
                if (match.isChallenger && match.canReschedule)
                  TextButton(
                    onPressed: () => _pickMatchDate(context, actions),
                    child: const Text('Değiştir'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _LineupBlock(
              match: match,
              onSetTeamSize: () => _pickTeamSizeOnly(context, actions),
            ),
          ],
        );

      // -----------------------------------------------------------------
      // AŞAMA 4 — Maç bitti: sonucu gir
      // -----------------------------------------------------------------
      case PendingMatchStage.awaitingResult:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (match.canReportScore) ...<Widget>[
              _HintText(
                match.isChallenger
                    ? 'Maç bitti. Skoru ve oyuncularınızın gol/asistlerini girin.'
                    : '${match.opponentTeamName} skoru 24 saat içinde girmedi; '
                        'skoru siz girebilirsiniz.',
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MatchResultScreen(
                      matchId: match.id,
                      myTeamId: match.myTeamId,
                      withScore: true,
                    ),
                  ),
                ),
                icon: const Icon(Icons.scoreboard_outlined, size: 18),
                label: const Text('Sonucu Gir'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ] else
              _HintText(
                'Maç tamamlandı. Skoru ${match.opponentTeamName} girecek; 24 saat '
                'içinde girmezse siz girebilirsiniz. Sonra Maç Geçmişi\'nden kendi '
                'oyuncularınızın gol/asistlerini girersiniz.',
              ),
            const SizedBox(height: 10),
            // Maçtan önce unutulduysa kadro hâlâ seçilebilir.
            _LineupBlock(match: match),
          ],
        );

      // -----------------------------------------------------------------
      // Süre doldu — sistem iptali
      // -----------------------------------------------------------------
      case PendingMatchStage.expired:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.loss.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: const Row(
            children: <Widget>[
              Icon(Icons.timer_off_rounded, color: AppColors.loss, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '1 hafta içinde iki taraf da onay vermediği için maç otomatik iptal edildi.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
    }
  }

  // -------------------------------------------------------------------
  // Yardımcı aksiyonlar
  // -------------------------------------------------------------------
  /// Sunucu çağrısını çalıştırır; hata olursa kullanıcıya gösterir.
  /// RPC'ler yetki ve durum geçişlerini denetlediği için hata gerçek
  /// bir kural ihlalini işaret eder (örn. sırası gelmemiş bir aksiyon).
  static Future<void> _run(
    BuildContext context,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (successMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(turkishMatchError(error))),
      );
    }
  }

  void _confirmReject(
    BuildContext context,
    MatchActions actions, {
    bool isWithdraw = false,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(isWithdraw ? 'Teklifi geri çek' : 'Teklifi reddet'),
        content: Text(
          isWithdraw
              ? '${match.opponentTeamName} takımına gönderdiğiniz maç teklifi iptal edilecek.'
              : '${match.opponentTeamName} takımının maç teklifi reddedilecek.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _run(
                context,
                () => isWithdraw
                    ? actions.cancel(match.id, reason: 'Teklif geri çekildi')
                    : actions.reject(match.id),
                successMessage:
                    isWithdraw ? 'Teklif geri çekildi.' : 'Teklif reddedildi.',
              );
            },
            child: Text(isWithdraw ? 'Geri Çek' : 'Reddet'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMatchDate(
    BuildContext context,
    MatchActions actions,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateUtils.dateOnly(now);
    final DateTime lastDate = now.add(const Duration(days: 90));

    // showDatePicker, başlangıç günü firstDate'ten önceyse hata veriyor.
    // Kayıtlı tarih geçmişte kaldıysa (ör. gece yarısına yakın maç) ya da
    // aralık dışındaysa varsayılana dön.
    DateTime initialDate = match.matchDate ?? now.add(const Duration(days: 1));
    if (initialDate.isBefore(today) || initialDate.isAfter(lastDate)) {
      initialDate = now.add(const Duration(days: 1));
    }

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastDate,
      locale: const Locale('tr', 'TR'),
    );
    if (date == null || !context.mounted) return;

    final DateTime? existing = match.matchDate;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: existing == null
          ? const TimeOfDay(hour: 21, minute: 0)
          : TimeOfDay.fromDateTime(existing),
    );
    if (time == null || !context.mounted) return;

    final DateTime picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // Takvim geçmiş günleri zaten engelliyor ama bugünün geçmiş bir saati
    // seçilebiliyor. Sunucu da reddediyor; kullanıcıyı istek atmadan uyar.
    if (!picked.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçmiş bir saat seçtin. Maç saati şu andan sonra olmalı.'),
        ),
      );
      return;
    }

    // Maç kilitleme: kaç kişilik olacağı gün/saatle birlikte kaydedilir.
    final int? teamSize = await showTeamSizePicker(
      context,
      initial: match.teamSize,
      hasLineup: match.myLineupCount > 0,
    );
    if (teamSize == null || !context.mounted) return;

    await _run(
      context,
      () => actions.setMatchDate(match.id, picked, teamSize: teamSize),
      successMessage: 'Maç tarihi ve kişi sayısı kaydedildi.',
    );
  }

  /// Eski maçlar: tarih belli ama kişi sayısı seçilmemiş.
  Future<void> _pickTeamSizeOnly(BuildContext context, MatchActions actions) async {
    final DateTime? date = match.matchDate;
    if (date == null) return;
    final int? teamSize = await showTeamSizePicker(context);
    if (teamSize == null || !context.mounted) return;
    await _run(
      context,
      () => actions.setMatchDate(match.id, date, teamSize: teamSize),
      successMessage: 'Maç ${teamSize}v$teamSize olarak kaydedildi.',
    );
  }
}

/// Maç kadrosu durumu: "Kadronuz 5/7" + Kadroyu Seç.
class _LineupBlock extends StatelessWidget {
  const _LineupBlock({required this.match, this.onSetTeamSize});

  final PendingMatch match;

  /// Kişi sayısı henüz seçilmemişse (eski maçlar) teklifi gönderen için.
  final VoidCallback? onSetTeamSize;

  @override
  Widget build(BuildContext context) {
    final int? size = match.teamSize;

    if (size == null) {
      if (match.isChallenger && match.canReschedule && onSetTeamSize != null) {
        return OutlinedButton.icon(
          onPressed: onSetTeamSize,
          icon: const Icon(Icons.groups_outlined, size: 18),
          label: const Text('Maç kaç kişilik? Belirle'),
        );
      }
      return const SizedBox.shrink();
    }
    if (!match.canPickLineup) return const SizedBox.shrink();

    final bool complete = match.isLineupComplete;
    final Color color = complete ? AppColors.win : AppColors.draw;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            complete ? Icons.check_circle_rounded : Icons.groups_outlined,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              complete
                  ? 'Maç kadronuz hazır (${size}v$size)'
                  : 'Maç kadronuz: ${match.myLineupCount}/$size',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => LineupPickerScreen.forMatch(match)),
            ),
            child: Text(complete ? 'Düzenle' : 'Kadroyu Seç'),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Küçük yardımcı widget'lar
// =====================================================================

/// 1 haftalık onay süresinin geri sayımı ve ilerleme çubuğu.
class _ReadinessCountdown extends StatelessWidget {
  const _ReadinessCountdown({required this.match});

  final PendingMatch match;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Duration left = match.timeLeftForReadiness;
    final int days = left.inDays;
    final int hours = left.inHours % 24;
    // 7 günün ne kadarı geçti?
    final double progress = 1 - (left.inMinutes / const Duration(days: 7).inMinutes);
    final bool isUrgent = days < 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.timer_outlined,
              size: 15,
              color: isUrgent ? AppColors.loss : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                days > 0
                    ? 'Karşılıklı onay için $days gün $hours saat kaldı'
                    : 'Son $hours saat! Onaylanmazsa maç otomatik iptal olur',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isUrgent ? AppColors.loss : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              isUrgent ? AppColors.loss : AppColors.draw,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarafların "Maça Hazırım" durumunu gösteren küçük çip.
class _ReadyChip extends StatelessWidget {
  const _ReadyChip({required this.label, required this.isReady});

  final String label;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = isReady ? AppColors.win : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isReady ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    );
  }
}
