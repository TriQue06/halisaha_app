import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/banner_ad_slot.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import '../notifications/notifications_screen.dart';
import '../pitches/pitch_detail_screen.dart';
import '../profile/goalkeeper_profile_editor.dart';
import 'widgets/month_calendar.dart';
import 'widgets/popular_pitch_card.dart';

/// Ana Sayfa.
///
/// Yukarıdan aşağıya sabit düzen:
///   1. En Popüler Sahalar (yatay kaydırmalı 3 kart)
///   2. "Kaleci Profili Oluştur" geniş CTA butonu
///   3. Takvim (bugün vurgulu)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserProfile? user = ref.watch(currentUserProvider);
    final AsyncValue<List<Pitch>> popular = ref.watch(popularPitchesProvider);
    final Goalkeeper? myGoalkeeper = ref.watch(myGoalkeeperProvider).valueOrNull;
    final List<CalendarEvent> events = ref.watch(calendarEventsProvider);
    final DateTime selectedDay = ref.watch(selectedDayProvider);
    final DateTime focusedMonth = ref.watch(focusedMonthProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _HomeHeader(user: user)),

            // ---------------------------------------------------------
            // 1. EN POPÜLER SAHALAR
            // ---------------------------------------------------------
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: 'En Popüler Sahalar',
                subtitle: 'En çok takım barındıran 3 halı saha',
                icon: Icons.local_fire_department_rounded,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 214,
                child: popular.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Sahalar yüklenemedi.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  data: (List<Pitch> list) {
                    if (list.isEmpty) {
                      return const Center(
                        child: Text('Henüz kayıtlı halı saha yok.'),
                      );
                    }
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final Pitch pitch = list[index];
                        return PopularPitchCard(
                          pitch: pitch,
                          rank: index + 1,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PitchDetailScreen(pitchId: pitch.id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // ---------------------------------------------------------
            // 2. KALECİ PROFİLİ OLUŞTUR (geniş CTA)
            // ---------------------------------------------------------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
                child: _GoalkeeperCtaCard(hasProfile: myGoalkeeper != null),
              ),
            ),

            // ---------------------------------------------------------
            // 3. TAKVİM
            // ---------------------------------------------------------
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Maç Takvimi',
                subtitle: 'Planlanmış maçlarınız',
                icon: Icons.calendar_month_rounded,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MonthCalendar(
                  focusedMonth: focusedMonth,
                  selectedDay: selectedDay,
                  events: events,
                  onDaySelected: (DateTime day) =>
                      ref.read(selectedDayProvider.notifier).state = day,
                  onMonthChanged: (DateTime month) =>
                      ref.read(focusedMonthProvider.notifier).state = month,
                ),
              ),
            ),
            // Reklam: takvimin altında, hiçbir aksiyon butonuna bitişik değil.
            const SliverToBoxAdapter(child: BannerAdSlot(
              padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
            )),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// Yeşil gradyanlı karşılama başlığı.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int unread = ref.watch(unreadNotificationCountProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[AppColors.darkSurfaceAlt, AppColors.darkBackground]
              : <Color>[AppColors.primaryGreen, AppColors.deepGreen],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusLg)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user == null ? 'Merhaba' : 'Merhaba, ${user!.firstName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Japon Kale',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'İzmir · Rakibini bul, sahaya çık',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          // Zil: okunmamış bildirim sayısını rozette gösterir.
          Material(
            color: Colors.white.withValues(alpha: 0.15),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Icon(
                      unread > 0
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: Colors.white,
                    ),
                    if (unread > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 17),
                          decoration: BoxDecoration(
                            color: AppColors.loss,
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Kaleci Profili Oluştur" — ana sayfanın orta bölümündeki dikkat çekici buton.
class _GoalkeeperCtaCard extends StatelessWidget {
  const _GoalkeeperCtaCard({required this.hasProfile});

  /// Kullanıcının zaten bir kaleci profili varsa metin ve ikon değişir.
  final bool hasProfile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const GoalkeeperProfileEditor()),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? <Color>[AppColors.midGreen, AppColors.deepGreen]
                  : <Color>[AppColors.primaryGreen, AppColors.midGreen],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.0 : 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sports_mma_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hasProfile ? 'Kaleci Profilini Düzenle' : 'Kaleci Profili Oluştur',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasProfile
                            ? 'İlçelerini ve müsaitlik bilgini güncel tut'
                            : 'Kaleci arayan takımlar seni bulsun',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
