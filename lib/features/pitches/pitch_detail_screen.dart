import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../core/utils/match_errors.dart';
import '../../core/utils/phone_launcher.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/moderation_repository.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import '../moderation/report_action_sheet.dart';
import '../teams/team_form_screen.dart';
import '../teams/team_profile_screen.dart';
import '../teams/widgets/pitch_leaderboard.dart';

/// Saha Detay Sayfası.
///
/// - Saha özellikleri ve fotoğraf placeholder'ı
/// - "Takımımı Bu Sahaya Kaydet/Oluştur" butonu (sadece takımı yoksa)
/// - Sahaya kayıtlı takımlar + G/B/M istatistikleri
/// - **MAÇ TEKLİFİ** butonu yalnızca kullanıcının BU sahada takımı varsa görünür.
class PitchDetailScreen extends ConsumerWidget {
  const PitchDetailScreen({super.key, required this.pitchId});

  final String pitchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Pitch?> pitchAsync = ref.watch(pitchByIdProvider(pitchId));
    final AsyncValue<List<Team>> teamsAsync = ref.watch(teamsForPitchProvider(pitchId));

    /// Teklif gönderme yetkisinin tek koşulu: bu sahada kayıtlı takımım var mı?
    final Team? myTeam = ref.watch(myTeamForPitchProvider(pitchId));

    /// Halihazırda aktif maçımız olan takımlar — onlara ikinci teklif
    /// gönderilemez (DB'de aynı çift için tek aktif maç kuralı var).
    final Set<String> busyOpponentIds = <String>{
      for (final PendingMatch m
          in ref.watch(pendingMatchesProvider).valueOrNull ?? const <PendingMatch>[])
        if (m.opponentTeamId.isNotEmpty) m.opponentTeamId,
    };

    final Pitch? pitch = pitchAsync.valueOrNull;
    if (pitch == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saha')),
        body: Center(
          child: pitchAsync.hasError
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Saha bilgisi yüklenemedi',
                  message: turkishMatchError(pitchAsync.error!),
                  action: OutlinedButton(
                    onPressed: () => ref.invalidate(pitchesProvider),
                    child: const Text('Tekrar dene'),
                  ),
                )
              // Liste geldi ama saha yok (kaldırılmış): sonsuza dek yükleme
              // göstergesi yerine açıkça söyle.
              : pitchAsync.hasValue
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Saha bulunamadı',
                      message: 'Bu saha artık listede değil.',
                    )
                  : const CircularProgressIndicator(),
        ),
      );
    }
    final List<Team> teams = teamsAsync.valueOrNull ?? const <Team>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              // Renk sabit: FlexibleSpaceBar başlığı AppBar'ın foregroundColor'ını
              // değil temanın metin rengini alıyor; açık temada koyu kalıp
              // yeşil/karartılmış zeminde okunmuyordu.
              title: Text(
                pitch.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 52, right: 16, bottom: 14),
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (pitch.imageUrl != null && pitch.imageUrl!.isNotEmpty)
                    Image.network(
                      pitch.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const PitchImagePlaceholder(iconSize: 64),
                    )
                  else
                    const PitchImagePlaceholder(iconSize: 64),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Saha bilgileri ------------------------------------------
          SliverToBoxAdapter(child: _PitchInfoSection(pitch: pitch)),

          // --- Takım oluşturma / takımım -------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: myTeam == null
                  ? FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                          builder: (_) => TeamFormScreen.create(pitch: pitch),
                        ),
                      ),
                      icon: const Icon(Icons.add_moderator_rounded),
                      label: const Text('Takımımı Bu Sahaya Kaydet'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    )
                  : _MyTeamBanner(team: myTeam),
            ),
          ),

          // --- Kayıtlı takımlar ----------------------------------------
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Kayıtlı Takımlar',
              subtitle: myTeam == null
                  ? 'Maç teklifi göndermek için önce bu sahaya takımını kaydet'
                  : '${teams.length} takım · Rakip seç ve teklif gönder',
              icon: Icons.shield_moon_rounded,
            ),
          ),
          if (teamsAsync.isLoading && !teamsAsync.hasValue)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (teamsAsync.hasError && !teamsAsync.hasValue)
            // Bağlantı hatası "bu sahada takım yok" gibi gösterilmez.
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Takımlar yüklenemedi',
                message: turkishMatchError(teamsAsync.error!),
                compact: true,
                action: OutlinedButton(
                  onPressed: () => ref.invalidate(teamsForPitchProvider(pitchId)),
                  child: const Text('Tekrar dene'),
                ),
              ),
            )
          else if (teams.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.groups_outlined,
                title: 'Bu sahada henüz takım yok',
                message: 'İlk takımı sen kur, rakipler gelsin.',
                compact: true,
              ),
            )
          else
            SliverList.separated(
              itemCount: teams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final Team team = teams[index];
                return Padding(
                  padding: EdgeInsets.fromLTRB(16, index == 0 ? 0 : 0, 16, 0),
                  child: _TeamRow(
                    team: team,
                    rank: index + 1,
                    // Kendi takımıma teklif gönderemem.
                    canChallenge: myTeam != null && myTeam.id != team.id,
                    hasActiveMatch: busyOpponentIds.contains(team.id),
                    isMyTeam: myTeam?.id == team.id,
                    onChallenge: () => _sendChallenge(context, ref, myTeam!, team, pitch),
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TeamProfileScreen(teamId: team.id),
                      ),
                    ),
                  ),
                );
              },
            ),

          // --- Gol / asist krallığı -------------------------------------
          const SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Krallık Yarışı',
              subtitle: 'Bu sahanın en golcü ve en çok asist yapan oyuncuları',
              icon: Icons.emoji_events_rounded,
            ),
          ),
          SliverToBoxAdapter(child: PitchLeaderboard(pitchId: pitchId)),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Aksiyonlar
  // -------------------------------------------------------------------
  void _sendChallenge(
    BuildContext context,
    WidgetRef ref,
    Team myTeam,
    Team opponent,
    Pitch pitch,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Maç Teklifi Gönder'),
        content: Text(
          '${opponent.name} takımına maç teklifi göndermek üzeresiniz.\n\n'
          'Rakip kabul ederse maç "Bekleyen Maçlar" listenize düşecek ve '
          'iki tarafın da 1 hafta içinde "Maça Hazırım" onayı vermesi gerekecek.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogContext).pop();
              try {
                await ref.read(matchActionsProvider).sendChallenge(
                      myTeamId: myTeam.id,
                      opponentTeamId: opponent.id,
                    );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('${opponent.name} takımına maç teklifi gönderildi.'),
                  ),
                );
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text(turkishMatchError(error))),
                );
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Saha bilgi bölümü
// =====================================================================
class _PitchInfoSection extends StatelessWidget {
  const _PitchInfoSection({required this.pitch});

  final Pitch pitch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${pitch.district} · ${pitch.address}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String feature in pitch.features)
                InfoPill(label: feature, icon: Icons.check_circle_outline_rounded),
              InfoPill(label: '${pitch.teamCount} takım', icon: Icons.groups_rounded),
              if (pitch.pricePerHour != null)
                InfoPill(
                  label: '${pitch.pricePerHour!.toStringAsFixed(0)} ₺/saat',
                  icon: Icons.payments_outlined,
                ),
            ],
          ),
          if (pitch.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              pitch.description,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => PhoneLauncher.call(context, pitch.phone),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('Sahayı Ara'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  // Harita uygulamasında saha adı + adresle arama.
                  onPressed: () => openExternalLink(
                    context,
                    'https://www.google.com/maps/search/?api=1&query='
                    '${Uri.encodeComponent('${pitch.name}, ${pitch.address}, ${pitch.district}, İzmir')}',
                  ),
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const Text('Yol Tarifi'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Takım satırı (G/B/M + MAÇ TEKLİFİ)
// =====================================================================
class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.team,
    required this.rank,
    required this.canChallenge,
    required this.hasActiveMatch,
    required this.isMyTeam,
    required this.onChallenge,
    required this.onOpen,
  });

  final Team team;
  final int rank;

  /// Butonun görünürlüğünü belirler: kullanıcının bu sahada takımı yoksa `false`.
  final bool canChallenge;

  /// Bu takımla zaten devam eden bir maç var mı? Varsa buton pasif.
  final bool hasActiveMatch;
  final bool isMyTeam;
  final VoidCallback onChallenge;

  /// Takım profiline (kadro + maç geçmişi) gider.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      color: isMyTeam ? theme.colorScheme.primary.withValues(alpha: 0.06) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
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
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          team.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (isMyTeam) ...<Widget>[
                        const SizedBox(width: 6),
                        const InfoPill(label: 'Takımım'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // G/B/M isim altında: sağda maç teklifi ve menüye
                  // yer kalsın diye.
                  Row(
                    children: <Widget>[
                      StatBadge.win(value: team.wins),
                      const SizedBox(width: 4),
                      StatBadge.draw(value: team.draws),
                      const SizedBox(width: 4),
                      StatBadge.loss(value: team.losses),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${team.points} puan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ---------------------------------------------------------
            // MAÇ TEKLİFİ — yalnızca kullanıcının bu sahada takımı varsa.
            // Takımı yoksa buton hiç render edilmez (gizli).
            // ---------------------------------------------------------
            if (canChallenge) ...<Widget>[
              const SizedBox(width: 8),
              FilledButton(
                onPressed: hasActiveMatch ? null : onChallenge,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                child: Text(hasActiveMatch ? 'MAÇ VAR' : 'MAÇ TEKLİFİ'),
              ),
            ],
            // Rapor et / engelle: takım kaptanı hakkında.
            if (!isMyTeam)
              ModerationMenuButton(
                userId: team.captainId,
                displayName: team.name,
                reportContext: ReportContext.team,
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// =====================================================================
// Kullanıcının bu sahadaki takımı
// =====================================================================
class _MyTeamBanner extends StatelessWidget {
  const _MyTeamBanner({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.verified_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Bu sahadaki takımın: ${team.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Diğer takımlara maç teklifi gönderebilirsin.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
