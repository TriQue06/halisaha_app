import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import '../../state/team_providers.dart';
import '../../core/utils/match_errors.dart';
import '../auth/complete_profile_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/main_shell.dart';
import '../teams/team_form_screen.dart';
import '../teams/team_profile_screen.dart';
import 'goalkeeper_profile_editor.dart';
import 'widgets/avatar_editor.dart';
import 'widgets/phone_editor.dart';

/// Profil sekmesi: kullanıcı bilgileri + "Takımlarım" / "Kaleci Profilim"
/// tabları. Maçlar ayrı sekmede; ayarlar sağ üstteki dişliden açılır.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserProfile? user = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                pinned: true,
                expandedHeight: 168,
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Ayarlar',
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _ProfileHeader(user: user),
                  collapseMode: CollapseMode.pin,
                ),
                bottom: const TabBar(
                  tabs: <Widget>[
                    Tab(text: 'Takımlarım'),
                    Tab(text: 'Kaleci Profilim'),
                  ],
                ),
              ),
            ];
          },
          body: Column(
            children: <Widget>[
              // Doğum tarihi ve telefon girişte zorunlu değil (Apple ile
              // girişte Apple bunları vermiyor); eksikse burada hatırlatılır.
              if (user != null &&
                  (user.fullName.isEmpty || user.birthDate == null || user.phone.isEmpty))
                _CompleteProfileBanner(user: user),
              const Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _MyTeamsTab(),
                    GoalkeeperProfileEditor(embedded: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eksik profil bilgisi hatırlatması.
///
/// Giriş akışını kesmiyoruz (App Store, Apple ile girişten sonra ek kayıt
/// ekranı istemiyor); eksikler uygulamanın içinde, isteğe bağlı olarak
/// tamamlanıyor.
class _CompleteProfileBanner extends StatelessWidget {
  const _CompleteProfileBanner({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> missing = <String>[
      if (user.fullName.isEmpty) 'adın',
      if (user.birthDate == null) 'doğum tarihin',
      if (user.phone.isEmpty) 'telefon numaran',
    ];

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CompleteProfileScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.info_outline_rounded,
                  size: 20, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Profilini tamamla: ${missing.join(' ve ')} eksik.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Üst bilgi: isim, doğum tarihi / yaş, telefon
// =====================================================================
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  /// Profil henüz yüklenmediyse null; alanlar yer tutucu gösterir.
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[AppColors.darkSurfaceAlt, AppColors.darkBackground]
              : <Color>[AppColors.primaryGreen, AppColors.deepGreen],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Dokununca fotoğraf yükle / değiştir / kaldır.
          GestureDetector(
            onTap: user == null ? null : () => showAvatarEditor(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  // Kullanıcının yüklediği ya da Google hesabından gelen fotoğraf.
                  foregroundImage: (user?.avatarUrl?.isNotEmpty ?? false)
                      ? NetworkImage(user!.avatarUrl!)
                      : null,
                  child: const Icon(Icons.person_rounded, size: 34, color: Colors.white),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.midGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  user == null
                      ? 'Profil yükleniyor...'
                      : (user.fullName.isNotEmpty ? user.fullName : 'Japon Kale oyuncusu'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                _HeaderInfoRow(
                  icon: Icons.cake_outlined,
                  text: user?.birthDate == null
                      ? 'Doğum tarihi eklenmemiş'
                      : '${DateFormat('d MMMM yyyy', 'tr_TR').format(user!.birthDate!)}'
                          ' · ${user!.age} yaşında',
                ),
                const SizedBox(height: 2),
                // Telefon tek kaynaktan yönetiliyor; düzenleme burada.
                InkWell(
                  onTap: () => showPhoneEditor(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: _HeaderInfoRow(
                          icon: Icons.phone_outlined,
                          text: user?.phone.isNotEmpty ?? false
                              ? user!.phone
                              : 'Telefon numarası ekle',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderInfoRow extends StatelessWidget {
  const _HeaderInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// "Takımlarım" sekmesi
// =====================================================================
class _MyTeamsTab extends ConsumerWidget {
  const _MyTeamsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Team>> teamsAsync = ref.watch(myTeamsProvider);

    if (teamsAsync.isLoading && !teamsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (teamsAsync.hasError && !teamsAsync.hasValue) {
      // Bağlantı hatası "takımın yok" gibi gösterilmez.
      return Center(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Takımların yüklenemedi',
          message: turkishMatchError(teamsAsync.error!),
          action: OutlinedButton.icon(
            onPressed: () => ref.invalidate(myTeamsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
        ),
      );
    }

    final List<Team> teams = teamsAsync.valueOrNull ?? const <Team>[];
    final Widget goToPitches = FilledButton.icon(
      onPressed: () => ref.read(selectedTabProvider.notifier).state = MainTab.pitches.index,
      icon: const Icon(Icons.add_moderator_rounded),
      label: Text(teams.isEmpty ? 'Takım kur' : 'Başka sahaya takım kur'),
    );

    if (teams.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.shield_outlined,
          title: 'Henüz bir takımın yok',
          message: 'Bir halı saha seçip takımını kur; o sahadaki takımlara maç '
              'teklifi gönderebilirsin.',
          action: goToPitches,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myTeamsProvider);
        try {
          await ref.read(myTeamsProvider.future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: <Widget>[
          for (final Team team in teams)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TeamSummaryCard(team: team),
            ),
          const SizedBox(height: 4),
          Center(child: goToPitches),
        ],
      ),
    );
  }
}

/// Takımın G/B/M özeti; dokununca takım profili. Kadro eksikse uyarır.
class _TeamSummaryCard extends ConsumerWidget {
  const _TeamSummaryCard({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<TeamPlayer>? roster = ref.watch(teamRosterProvider(team.id)).valueOrNull;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TeamProfileScreen(teamId: team.id)),
        ),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(Icons.shield_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${team.played} maç · ${team.points} puan · Kaptan',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                StatBadge.win(value: team.wins),
                const SizedBox(width: 5),
                StatBadge.draw(value: team.draws),
                const SizedBox(width: 5),
                StatBadge.loss(value: team.losses),
              ],
            ),
          ],
        ),
            // Eski takımlarda kadro yok; teklif gönderip kabul etmek için şart.
            if (roster != null && roster.length < kMinRosterSize) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: AppColors.loss.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.warning_amber_rounded, color: AppColors.loss, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kadronda ${roster.length} oyuncu var. Maç teklifi için '
                        'en az $kMinRosterSize gerekli.',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                          builder: (_) =>
                              TeamFormScreen.editRoster(team: team),
                        ),
                      ),
                      child: const Text('Kadro ekle'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
