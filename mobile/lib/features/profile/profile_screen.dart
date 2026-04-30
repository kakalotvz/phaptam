import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final darkMode = ref.watch(darkModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ho so')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Icon(isLoggedIn ? Icons.person : Icons.lock_outline),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLoggedIn ? 'Phat tu' : 'Chua dang nhap',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          isLoggedIn
                              ? 'Quan ly yeu thich va playlist'
                              : 'Dang nhap de luu tien trinh nghe',
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () =>
                        ref.read(isLoggedInProvider.notifier).toggle(),
                    child: Text(isLoggedIn ? 'Thoat' : 'Dang nhap'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _NavTile(
            icon: Icons.favorite_border,
            title: 'Yeu thich',
            subtitle: 'Audio va video da luu',
            locked: !isLoggedIn,
          ),
          _NavTile(
            icon: Icons.playlist_play,
            title: 'Playlist',
            subtitle: 'Danh sach kinh ca nhan',
            locked: !isLoggedIn,
          ),
          _NavTile(
            icon: Icons.history,
            title: 'Lich su xem',
            subtitle: 'Video da xem gan day',
            locked: !isLoggedIn,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Giao dien toi'),
            value: darkMode,
            onChanged: (value) =>
                ref.read(darkModeProvider.notifier).setEnabled(value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Thong bao'),
            value: true,
            onChanged: (_) {},
          ),
          const Divider(height: 34),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Gop y va bao loi noi dung'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFeedback(context),
          ),
        ],
      ),
    );
  }

  void _showFeedback(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gui gop y'),
        content: const TextField(
          maxLines: 4,
          decoration: InputDecoration(hintText: 'Noi dung gop y hoac bao loi'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Gui'),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.locked,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(locked ? '$subtitle • Can dang nhap' : subtitle),
      trailing: Icon(locked ? Icons.lock_outline : Icons.chevron_right),
    );
  }
}
