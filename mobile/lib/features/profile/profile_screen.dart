import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/content_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final darkMode = ref.watch(darkModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
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
                          isLoggedIn ? 'Phật tử' : 'Chưa đăng nhập',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          isLoggedIn
                              ? 'Quản lý yêu thích và playlist'
                              : 'Đăng nhập để lưu tiến trình nghe',
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (isLoggedIn) {
                        ref.read(isLoggedInProvider.notifier).logout();
                      } else {
                        context.push('/login');
                      }
                    },
                    child: Text(isLoggedIn ? 'Thoát' : 'Đăng nhập'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _NavTile(
            icon: Icons.favorite_border,
            title: 'Yêu thích',
            subtitle: 'Audio và video đã lưu',
            locked: !isLoggedIn,
          ),
          if (!isLoggedIn) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/register'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Đăng ký tài khoản'),
            ),
            TextButton(
              onPressed: () => context.push('/forgot-password'),
              child: const Text('Quên mật khẩu?'),
            ),
          ],
          _NavTile(
            icon: Icons.playlist_play,
            title: 'Playlist',
            subtitle: 'Danh sách kinh cá nhân',
            locked: !isLoggedIn,
          ),
          _NavTile(
            icon: Icons.history,
            title: 'Lịch sử xem',
            subtitle: 'Video đã xem gần đây',
            locked: !isLoggedIn,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Giao diện tối'),
            value: darkMode,
            onChanged: (value) =>
                ref.read(darkModeProvider.notifier).setEnabled(value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Thông báo'),
            value: true,
            onChanged: (_) {},
          ),
          const Divider(height: 34),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Góp ý và báo lỗi nội dung'),
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
        title: const Text('Gửi góp ý'),
        content: const TextField(
          maxLines: 4,
          decoration: InputDecoration(hintText: 'Nội dung góp ý hoặc báo lỗi'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Gửi'),
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
      subtitle: Text(locked ? '$subtitle • Cần đăng nhập' : subtitle),
      trailing: Icon(locked ? Icons.lock_outline : Icons.chevron_right),
    );
  }
}
