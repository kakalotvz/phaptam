import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/media_downloads.dart';
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
          if (isLoggedIn) const _DownloadRestorePrompt(),
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
            icon: Icons.download_done_outlined,
            title: 'Danh sách đã tải',
            subtitle: 'Quản lý và tải lại nội dung offline',
            locked: !isLoggedIn,
            onTap: isLoggedIn
                ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DownloadedMediaScreen(),
                    ),
                  )
                : null,
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(locked ? '$subtitle • Cần đăng nhập' : subtitle),
      trailing: Icon(locked ? Icons.lock_outline : Icons.chevron_right),
      onTap: locked ? null : onTap,
    );
  }
}

class _DownloadRestorePrompt extends ConsumerStatefulWidget {
  const _DownloadRestorePrompt();

  @override
  ConsumerState<_DownloadRestorePrompt> createState() =>
      _DownloadRestorePromptState();
}

class _DownloadRestorePromptState
    extends ConsumerState<_DownloadRestorePrompt> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final manifest = ref.watch(downloadManifestProvider);
    final local = ref.watch(mediaDownloadsProvider);
    manifest.whenOrNull(
      data: (remoteItems) => local.whenOrNull(
        data: (localState) {
          if (_checking || remoteItems.isEmpty) return;
          _checking = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybePrompt(remoteItems, localState);
          });
        },
      ),
    );
    return const SizedBox.shrink();
  }

  Future<void> _maybePrompt(
    List<RemoteDownload> remoteItems,
    MediaDownloadState localState,
  ) async {
    final shouldPrompt = await shouldPromptDownloadRestore(
      remoteItems,
      localState,
    );
    if (!mounted || !shouldPrompt) return;
    final missing = remoteItems
        .where((item) => !localState.isDownloaded(item.mediaKey))
        .toList();
    final restore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục nội dung offline?'),
        content: Text(
          'Tài khoản của bạn có ${missing.length} nội dung từng tải về, nhưng thiết bị này chưa có file offline. Bạn muốn tải lại ngay bây giờ không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tải lại'),
          ),
        ],
      ),
    );
    await markDownloadRestorePromptSeen();
    if (!mounted || restore != true) return;
    await _downloadRemoteItems(context, ref, missing);
  }
}

class DownloadedMediaScreen extends ConsumerStatefulWidget {
  const DownloadedMediaScreen({super.key});

  @override
  ConsumerState<DownloadedMediaScreen> createState() =>
      _DownloadedMediaScreenState();
}

class _DownloadedMediaScreenState extends ConsumerState<DownloadedMediaScreen> {
  final Set<String> _selected = {};
  bool _running = false;
  bool _paused = false;
  bool _cancelled = false;

  @override
  Widget build(BuildContext context) {
    final manifest = ref.watch(downloadManifestProvider);
    final local = ref.watch(mediaDownloadsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách đã tải')),
      body: manifest.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        data: (items) {
          final grouped = _groupDownloads(items);
          final selectedItems = items
              .where((item) => _selected.contains(item.mediaKey))
              .toList();
          final actionItems = selectedItems.isEmpty ? items : selectedItems;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Những nội dung bạn từng tải sẽ được lưu theo tài khoản để có thể tải lại trên thiết bị mới.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _running || actionItems.isEmpty
                    ? null
                    : () => _download(actionItems),
                icon: const Icon(Icons.download_for_offline_outlined),
                label: Text(
                  _selected.isEmpty
                      ? 'Tải toàn bộ'
                      : 'Tải ${_selected.length} mục đã chọn',
                ),
              ),
              if (_running) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _paused = !_paused),
                        icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                        label: Text(_paused ? 'Tiếp tục' : 'Tạm dừng'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _cancelled = true),
                        icon: const Icon(Icons.close),
                        label: const Text('Hủy'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.download_done_outlined),
                    title: Text('Chưa có nội dung đã tải'),
                  ),
                ),
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 8),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final item in entry.value)
                  local.when(
                    loading: () => _DownloadListTile(
                      item: item,
                      selected: _selected.contains(item.mediaKey),
                      downloaded: false,
                      sizeBytes: 0,
                      onSelected: _toggleSelected,
                      onDownload: _running ? null : () => _download([item]),
                      onDelete: _running ? null : () => _delete(item),
                    ),
                    error: (error, stackTrace) => _DownloadListTile(
                      item: item,
                      selected: _selected.contains(item.mediaKey),
                      downloaded: false,
                      sizeBytes: 0,
                      onSelected: _toggleSelected,
                      onDownload: _running ? null : () => _download([item]),
                      onDelete: _running ? null : () => _delete(item),
                    ),
                    data: (state) => _DownloadListTile(
                      item: item,
                      selected: _selected.contains(item.mediaKey),
                      downloaded: state.isDownloaded(item.mediaKey),
                      sizeBytes: state.items[item.mediaKey]?.sizeBytes ?? 0,
                      onSelected: _toggleSelected,
                      onDownload: _running ? null : () => _download([item]),
                      onDelete: _running ? null : () => _delete(item),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _toggleSelected(String key, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
    });
  }

  Future<void> _download(List<RemoteDownload> items) async {
    setState(() {
      _running = true;
      _paused = false;
      _cancelled = false;
    });
    try {
      for (final item in items) {
        while (_paused && !_cancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (_cancelled) break;
        await ref
            .read(mediaDownloadsProvider.notifier)
            .download(
              key: item.mediaKey,
              title: item.title,
              url: item.url,
              thumbnailUrl: item.thumbnailUrl,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cancelled ? 'Đã hủy tải' : 'Đã tải xong')),
        );
      }
    } finally {
      ref.invalidate(downloadManifestProvider);
      if (mounted) {
        setState(() {
          _running = false;
          _paused = false;
          _cancelled = false;
        });
      }
    }
  }

  Future<void> _delete(RemoteDownload item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa khỏi danh sách đã tải?'),
        content: const Text(
          'Tệp offline trên thiết bị sẽ bị xóa để giải phóng dung lượng. Mục này cũng sẽ được xóa khỏi danh sách đã tải của tài khoản.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(mediaDownloadsProvider.notifier)
        .remove(item.mediaKey, deleteRemote: true);
    ref.invalidate(downloadManifestProvider);
    setState(() => _selected.remove(item.mediaKey));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa khỏi danh sách đã tải')),
      );
    }
  }
}

class _DownloadListTile extends StatelessWidget {
  const _DownloadListTile({
    required this.item,
    required this.selected,
    required this.downloaded,
    required this.sizeBytes,
    required this.onSelected,
    required this.onDownload,
    required this.onDelete,
  });

  final RemoteDownload item;
  final bool selected;
  final bool downloaded;
  final int sizeBytes;
  final void Function(String key, bool selected) onSelected;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onSelected(item.mediaKey, value ?? false),
            ),
            Icon(_downloadIcon(item.mediaType)),
          ],
        ),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(_downloadStatus(downloaded, sizeBytes)),
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: downloaded ? 'Đã tải' : 'Tải mục này',
              onPressed: downloaded ? null : onDownload,
              icon: Icon(
                downloaded ? Icons.download_done : Icons.download_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Xóa khỏi danh sách đã tải',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

String _downloadStatus(bool downloaded, int sizeBytes) {
  if (!downloaded) return 'Chưa tải trên thiết bị này';
  final size = _formatBytes(sizeBytes);
  return size.isEmpty ? 'Đã có trên thiết bị' : 'Đã có trên thiết bị • $size';
}

Map<String, List<RemoteDownload>> _groupDownloads(List<RemoteDownload> items) {
  final result = <String, List<RemoteDownload>>{};
  for (final item in items) {
    result.putIfAbsent(_downloadTypeLabel(item.mediaType), () => []).add(item);
  }
  return result;
}

String _downloadTypeLabel(String type) {
  return switch (type) {
    'audio' => 'Kinh audio',
    'video' => 'Videos',
    'meditation' => 'Thiền',
    _ => type.trim().isEmpty ? 'Khác' : type,
  };
}

IconData _downloadIcon(String type) {
  return switch (type) {
    'audio' => Icons.headphones_outlined,
    'video' => Icons.play_circle_outline,
    'meditation' => Icons.self_improvement_outlined,
    _ => Icons.download_outlined,
  };
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index += 1;
  }
  final digits = value >= 10 || index == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[index]}';
}

Future<void> _downloadRemoteItems(
  BuildContext context,
  WidgetRef ref,
  List<RemoteDownload> items,
) async {
  try {
    for (final item in items) {
      await ref
          .read(mediaDownloadsProvider.notifier)
          .download(
            key: item.mediaKey,
            title: item.title,
            url: item.url,
            thumbnailUrl: item.thumbnailUrl,
          );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tải lại nội dung offline')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
