import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
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
                    onPressed: () async {
                      if (isLoggedIn) {
                        await ref.read(isLoggedInProvider.notifier).logout();
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
            onTap: () => _showFeedback(context, isLoggedIn: isLoggedIn),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Điều khoản sử dụng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTerms(context),
          ),
        ],
      ),
    );
  }

  void _showFeedback(BuildContext context, {required bool isLoggedIn}) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi góp ý'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isLoggedIn) ...[
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên',
                    hintText: 'Nhập họ tên của bạn',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'email@example.com',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  hintText: 'Nội dung góp ý hoặc báo lỗi',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final message = controller.text.trim();
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final emailValid = RegExp(
                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
              ).hasMatch(email);
              if (message.isEmpty ||
                  (!isLoggedIn && (name.isEmpty || !emailValid))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập đầy đủ thông tin hợp lệ'),
                  ),
                );
                return;
              }
              try {
                await apiClient.post('/feedback', {
                  'content': message,
                  'type': 'FEEDBACK',
                  if (isLoggedIn) 'userId': apiClient.currentUserId,
                  if (!isLoggedIn) 'guestName': name,
                  if (!isLoggedIn) 'guestEmail': email,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Đã gửi góp ý')));
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Điều khoản sử dụng'),
        content: const SingleChildScrollView(
          child: Text(
            'Khi sử dụng Pháp Tâm, bạn đồng ý dùng ứng dụng cho mục đích nghe, đọc, xem nội dung Phật pháp, thiền tập, lưu tiến trình cá nhân, tạo lịch nhắc tụng kinh và gửi góp ý/báo lỗi nội dung.\n\n'
            'Tài khoản và dữ liệu cá nhân: khi đăng ký hoặc đăng nhập, ứng dụng có thể lưu thông tin tài khoản, danh sách yêu thích, playlist, lịch sử, tiến trình nghe/đọc và lịch nhắc tụng kinh để đồng bộ trải nghiệm của bạn. Nếu gửi góp ý khi chưa đăng nhập, họ tên và email bạn nhập chỉ dùng để quản trị viên liên hệ hoặc xử lý phản hồi.\n\n'
            'Quyền trên thiết bị: ứng dụng cần Internet để tải nội dung; thông báo để nhắc lịch tụng kinh nếu bạn bật; quyền ảnh/thư viện chỉ được dùng khi bạn chọn lưu ảnh trích dẫn sau khi chia sẻ. Ứng dụng không tự ý đọc, tải lên hoặc chia sẻ ảnh cá nhân của bạn.\n\n'
            'Nội dung và chia sẻ: nội dung trong ứng dụng nhằm hỗ trợ học hỏi, thực hành và tham khảo. Khi chia sẻ trích dẫn hoặc tin bài, bạn chịu trách nhiệm về ngữ cảnh chia sẻ và không sử dụng ứng dụng để phát tán nội dung trái pháp luật, xúc phạm, lừa đảo hoặc gây hại cho người khác.\n\n'
            'Góp ý và báo lỗi: phản hồi của bạn được gửi đến hệ thống quản trị để kiểm tra, cải thiện chất lượng nội dung và trải nghiệm. Vui lòng không gửi mật khẩu, mã OTP, thông tin thanh toán hoặc dữ liệu nhạy cảm trong nội dung góp ý.\n\n'
            'Pháp Tâm có thể cập nhật tính năng, nội dung và điều khoản để phù hợp yêu cầu vận hành, an toàn người dùng và chính sách phân phối ứng dụng. Việc tiếp tục sử dụng ứng dụng sau cập nhật được hiểu là bạn đồng ý với phiên bản điều khoản mới.',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
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
