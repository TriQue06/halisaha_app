import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

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
          ],
        ),
      ),
    );
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
              const InfoPill(label: 'Meydan okuyan sizsiniz', icon: Icons.bolt_rounded),
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
          'MEYDAN OKUNDU',
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${match.opponentPhone} aranıyor...')),
            ),
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
    final PendingMatchesController controller = ref.read(pendingMatchesProvider.notifier);

    switch (match.stage) {
      // -----------------------------------------------------------------
      // AŞAMA 1a — Bize meydan okundu: Kabul / Reddet
      // -----------------------------------------------------------------
      case PendingMatchStage.invitationReceived:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _HintText(
              '${match.opponentTeamName} size meydan okudu. Kabul ederseniz '
              'iki tarafın da 1 hafta içinde "Maça Hazırım" onayı vermesi gerekir.',
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmReject(context, controller),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.loss),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      controller.acceptChallenge(match.id);
                      _snack(context, 'Meydan okuma kabul edildi. Şimdi "Maça Hazırım" onayı verin.');
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Kabul Et'),
                  ),
                ),
              ],
            ),
          ],
        );

      // -----------------------------------------------------------------
      // AŞAMA 1b — Biz meydan okuduk: rakibin yanıtını bekliyoruz
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
              onPressed: () => _confirmReject(context, controller, isWithdraw: true),
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
                onPressed: () {
                  controller.markReady(match.id);
                  _snack(context, 'Onayınız kaydedildi.');
                },
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
          // Gün ve saati yalnızca meydan okuyan takım girer.
          return match.isChallenger
              ? FilledButton.icon(
                  onPressed: () => _pickMatchDate(context, controller),
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: const Text('Maç Gün ve Saatini Belirle'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                )
              : _HintText(
                  'İki taraf da hazır. ${match.opponentTeamName} maç gün ve saatini girecek.',
                );
        }
        return Row(
          children: <Widget>[
            Expanded(
              child: _HintText(
                'Maç ${DateFormat("d MMMM EEEE, HH:mm", "tr_TR").format(match.matchDate!)} '
                'tarihinde ${match.pitchName} sahasında.',
              ),
            ),
            if (match.isChallenger)
              TextButton(
                onPressed: () => _pickMatchDate(context, controller),
                child: const Text('Değiştir'),
              ),
          ],
        );

      // -----------------------------------------------------------------
      // AŞAMA 4 — Maç bitti: sonucu gir
      // -----------------------------------------------------------------
      case PendingMatchStage.awaitingResult:
        if (!match.isChallenger) {
          return _HintText(
            'Maç tamamlandı. Sonucu ${match.opponentTeamName} girecek; '
            'istatistikleriniz otomatik güncellenecek.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _HintText('Maç nasıl sonlandı?'),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ResultButton(
                    label: 'Kazandık',
                    color: AppColors.win,
                    icon: Icons.emoji_events_rounded,
                    onPressed: () => _reportResult(context, controller, TeamOutcome.win),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultButton(
                    label: 'Berabere',
                    color: AppColors.draw,
                    icon: Icons.handshake_rounded,
                    onPressed: () => _reportResult(context, controller, TeamOutcome.draw),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultButton(
                    label: 'Kaybettik',
                    color: AppColors.loss,
                    icon: Icons.trending_down_rounded,
                    onPressed: () => _reportResult(context, controller, TeamOutcome.loss),
                  ),
                ),
              ],
            ),
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
  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _confirmReject(
    BuildContext context,
    PendingMatchesController controller, {
    bool isWithdraw = false,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(isWithdraw ? 'Meydan okumayı geri çek' : 'Meydan okumayı reddet'),
        content: Text(
          isWithdraw
              ? '${match.opponentTeamName} takımına gönderdiğiniz meydan okuma iptal edilecek.'
              : '${match.opponentTeamName} takımının meydan okuması reddedilecek.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () {
              controller.rejectChallenge(match.id);
              Navigator.of(dialogContext).pop();
              _snack(context, isWithdraw ? 'Meydan okuma geri çekildi.' : 'Meydan okuma reddedildi.');
            },
            child: Text(isWithdraw ? 'Geri Çek' : 'Reddet'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMatchDate(
    BuildContext context,
    PendingMatchesController controller,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: match.matchDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('tr', 'TR'),
    );
    if (date == null || !context.mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 21, minute: 0),
    );
    if (time == null || !context.mounted) return;

    controller.setMatchDate(
      match.id,
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
    _snack(context, 'Maç tarihi kaydedildi.');
  }

  void _reportResult(
    BuildContext context,
    PendingMatchesController controller,
    TeamOutcome outcome,
  ) {
    controller.reportResult(match.id, outcome);
    _snack(
      context,
      switch (outcome) {
        TeamOutcome.win => 'Galibiyet kaydedildi. Tebrikler!',
        TeamOutcome.draw => 'Beraberlik kaydedildi.',
        TeamOutcome.loss => 'Mağlubiyet kaydedildi.',
      },
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

class _ResultButton extends StatelessWidget {
  const _ResultButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        elevation: 0,
        minimumSize: const Size(0, 62),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
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
