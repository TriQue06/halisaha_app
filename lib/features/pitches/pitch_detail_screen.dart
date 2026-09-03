import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/match_errors.dart';
import '../../core/utils/phone_launcher.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import '../profile/widgets/phone_editor.dart';

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
                  message: pitchAsync.error.toString(),
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
              title: Text(
                pitch.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              titlePadding: const EdgeInsets.only(left: 52, right: 16, bottom: 14),
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
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
                      onPressed: () => _showCreateTeamSheet(context, ref, pitch),
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
          if (teams.isEmpty)
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
                  ),
                );
              },
            ),
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

  void _showCreateTeamSheet(BuildContext context, WidgetRef ref, Pitch pitch) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _CreateTeamSheet(pitch: pitch),
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
          OutlinedButton.icon(
            onPressed: () => PhoneLauncher.call(context, pitch.phone),
            icon: const Icon(Icons.phone_outlined, size: 18),
            label: Text('Sahayı Ara · ${pitch.phone}'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
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
  });

  final Team team;
  final int rank;

  /// Butonun görünürlüğünü belirler: kullanıcının bu sahada takımı yoksa `false`.
  final bool canChallenge;

  /// Bu takımla zaten devam eden bir maç var mı? Varsa buton pasif.
  final bool hasActiveMatch;
  final bool isMyTeam;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      color: isMyTeam ? theme.colorScheme.primary.withValues(alpha: 0.06) : null,
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
                  const SizedBox(height: 2),
                  Text(
                    '${team.played} maç · ${team.points} puan',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                StatBadge.win(value: team.wins),
                const SizedBox(width: 4),
                StatBadge.draw(value: team.draws),
                const SizedBox(width: 4),
                StatBadge.loss(value: team.losses),
              ],
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
          ],
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

// =====================================================================
// Takım oluşturma formu (BottomSheet)
// =====================================================================
class _CreateTeamSheet extends ConsumerStatefulWidget {
  const _CreateTeamSheet({required this.pitch});

  final Pitch pitch;

  @override
  ConsumerState<_CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends ConsumerState<_CreateTeamSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    try {
      await ref.read(createTeamProvider)(
        pitchId: widget.pitch.id,
        name: _nameController.text.trim(),
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.pitch.name} sahasına takımın kaydedildi.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Takım oluşturulamadı: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Numara olmadan takım kurulamaz (veritabanı da reddediyor).
    final bool hasPhone = (ref.watch(currentUserProvider)?.phone ?? '').isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Takımını Oluştur',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.pitch.name,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Takım Adı',
                hintText: 'Örn. Bornova Kartalları',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
              validator: (String? value) {
                if (value == null || value.trim().length < 3) {
                  return 'Takım adı en az 3 karakter olmalı.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Numara elle girilmiyor: profildeki numara kullanılır.
            const ContactPhoneNotice(label: 'Takım iletişim numarası'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: hasPhone ? _submit : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Takımı Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
