import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../state/app_providers.dart';
import '../shell/main_shell.dart';

/// Bildirimler ekranı.
///
/// Bildirimleri veritabanı trigger'ları üretiyor (maç teklifi geldi, kabul
/// edildi, program yapıldı, otomatik iptal...). Bu ekran onları listeler,
/// okundu işaretler ve silmeye izin verir.
///
/// Bir bildirime dokunmak onu okundu yapar; maçla ilgiliyse kullanıcıyı
/// "Profilim → Takımım" sekmesine götürür, çünkü aksiyon orada alınır.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppNotification>> notifications =
        ref.watch(notificationsProvider);
    final int unread = ref.watch(unreadNotificationCountProvider);

    Future<void> refresh() async {
      ref.invalidate(notificationsProvider);
      await ref.read(notificationsProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: <Widget>[
          if (unread > 0)
            TextButton(
              onPressed: () => ref.read(notificationActionsProvider).markAllRead(),
              child: const Text('Tümünü okundu yap'),
            ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Bildirimler yüklenemedi',
            message: error.toString(),
          ),
        ),
        data: (List<AppNotification> items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const <Widget>[
                  SizedBox(height: 72),
                  EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'Bildirimin yok',
                    message: 'Maç teklifi aldığında ya da bir maçın durumu '
                        'değiştiğinde burada göreceksin.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) =>
                  _NotificationTile(notification: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool unread = !notification.isRead;

    return Dismissible(
      key: ValueKey<String>(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => ref.read(notificationActionsProvider).delete(notification.id),
      child: Card(
        margin: EdgeInsets.zero,
        // Okunmamışlar hafif vurgulu arka planla ayrışır.
        color: unread ? theme.colorScheme.primary.withValues(alpha: 0.07) : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: () => _onTap(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.13),
                  child: Icon(
                    notification.kind.icon,
                    size: 19,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              notification.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6, top: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (notification.body.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          notification.body,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        notification.relativeTime,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final NavigatorState navigator = Navigator.of(context);

    if (!notification.isRead) {
      await ref.read(notificationActionsProvider).markRead(notification.id);
    }

    // Maçla ilgili bildirimlerde aksiyon "Profilim → Takımım"da alınır.
    if (notification.kind.opensMyTeam) {
      ref.read(selectedTabProvider.notifier).state = MainTab.profile.index;
      if (navigator.canPop()) navigator.pop();
    }
  }
}
