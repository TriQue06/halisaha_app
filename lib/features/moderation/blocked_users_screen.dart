import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/common_widgets.dart';
import '../../data/moderation_repository.dart';
import '../../state/moderation_providers.dart';

/// Ayarlar → Engellenen kullanıcılar: engeli kaldırma.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BlockedUser>> blocked =
        ref.watch(blockedUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Engellenen kullanıcılar')),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Liste yüklenemedi.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(blockedUsersProvider),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
        data: (List<BlockedUser> users) {
          if (users.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.block_rounded,
                title: 'Engellediğin kimse yok',
                message:
                    'Bir kaleciyi veya takımı ⋮ menüsünden engelleyebilirsin.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (BuildContext context, int index) =>
                _BlockedUserTile(user: users[index]),
          );
        },
      ),
    );
  }
}

class _BlockedUserTile extends ConsumerStatefulWidget {
  const _BlockedUserTile({required this.user});

  final BlockedUser user;

  @override
  ConsumerState<_BlockedUserTile> createState() => _BlockedUserTileState();
}

class _BlockedUserTileState extends ConsumerState<_BlockedUserTile> {
  bool _isBusy = false;

  Future<void> _unblock() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _isBusy = true);
    try {
      await ref.read(moderationActionsProvider).unblock(widget.user.userId);
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.user.name} için engel kaldırıldı.')),
      );
    } catch (_) {
      if (mounted) setState(() => _isBusy = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Engel kaldırılamadı. Tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? avatar = widget.user.avatarUrl;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundImage:
            (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
        child: Icon(Icons.person_rounded, color: theme.colorScheme.primary),
      ),
      title: Text(widget.user.name),
      subtitle: Text(
        '${DateFormat('d MMMM yyyy', 'tr_TR').format(widget.user.blockedAt)} tarihinde engellendi',
      ),
      trailing: _isBusy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(onPressed: _unblock, child: const Text('Engeli kaldır')),
    );
  }
}
