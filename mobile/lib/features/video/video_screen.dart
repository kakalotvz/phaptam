import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/content_cards.dart';
import '../content/content_models.dart';
import '../content/content_providers.dart';

class VideoScreen extends ConsumerWidget {
  const VideoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(videoListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pháp thoại')),
      body: videos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LoadError(
          message: 'Chưa tải được video',
          onRetry: () => ref.invalidate(videoListProvider),
        ),
        data: (items) {
          final teachers = items
              .map((e) => e.teacher)
              .where((teacher) => teacher.trim().isNotEmpty)
              .toSet()
              .toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(videoListProvider);
              await ref.read(videoListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                if (teachers.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final teacher in teachers)
                        FilterChip(
                          label: Text(teacher),
                          selected: false,
                          onSelected: (_) {},
                        ),
                    ],
                  ),
                if (teachers.isNotEmpty) const SizedBox(height: 18),
                if (items.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.video_library_outlined),
                      title: Text('Chưa có video'),
                      subtitle: Text(
                        'Thêm video trong admin để hiển thị tại đây.',
                      ),
                    ),
                  ),
                for (final video in items) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _showVideoPlayer(context, video),
                    child: VideoCard(video: video),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVideoPlayer(BuildContext context, VideoItem video) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _VideoPlayerSheet(video: video),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.wifi_off_outlined),
          title: Text(message),
          trailing: IconButton(
            tooltip: 'Tải lại',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ),
      ),
    );
  }
}

class _VideoPlayerSheet extends StatefulWidget {
  const _VideoPlayerSheet({required this.video});

  final VideoItem video;

  @override
  State<_VideoPlayerSheet> createState() => _VideoPlayerSheetState();
}

class _VideoPlayerSheetState extends State<_VideoPlayerSheet> {
  double speed = 1;
  String repeatMode = 'once';
  int customRepeatCount = 5;
  Duration? sleepTimer;

  String get repeatLabel => switch (repeatMode) {
    'three' => 'Lặp 3 lần',
    'custom' => 'Lặp $customRepeatCount lần',
    'forever' => 'Lặp liên tục',
    _ => 'Lặp 1 lần',
  };

  Future<void> pickSleepTimer() async {
    final picked = await showModalBottomSheet<Duration>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('Tắt hẹn giờ'),
                onTap: () => Navigator.pop(context, Duration.zero),
              ),
              for (final minutes in const [10, 15, 30, 60])
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: Text('$minutes phút'),
                  onTap: () =>
                      Navigator.pop(context, Duration(minutes: minutes)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() => sleepTimer = picked == Duration.zero ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                video.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.play_circle_outline)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            video.title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('${video.teacher} • ${video.topic}'),
          const SizedBox(height: 18),
          IconButton.filled(
            onPressed: () {},
            iconSize: 34,
            icon: const Icon(Icons.play_arrow),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              PopupMenuButton<double>(
                onSelected: (value) => setState(() => speed = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: .75, child: Text('Tốc độ 0.75x')),
                  PopupMenuItem(value: 1, child: Text('Tốc độ 1.0x')),
                  PopupMenuItem(value: 1.25, child: Text('Tốc độ 1.25x')),
                  PopupMenuItem(value: 1.5, child: Text('Tốc độ 1.5x')),
                ],
                child: Chip(
                  avatar: const Icon(Icons.speed, size: 18),
                  label: Text(
                    'Tốc độ ${speed.toStringAsFixed(speed == 1 ? 1 : 2)}x',
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => setState(() => repeatMode = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'once', child: Text('Lặp lại 1 lần')),
                  PopupMenuItem(value: 'three', child: Text('Lặp lại 3 lần')),
                  PopupMenuItem(
                    value: 'forever',
                    child: Text('Lặp lại liên tục'),
                  ),
                  PopupMenuItem(value: 'custom', child: Text('Tùy chỉnh')),
                ],
                child: Chip(
                  avatar: const Icon(Icons.repeat, size: 18),
                  label: Text(repeatLabel),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.bedtime_outlined, size: 18),
                label: Text(
                  sleepTimer == null
                      ? 'Hẹn giờ'
                      : '${sleepTimer!.inMinutes} phút',
                ),
                onPressed: pickSleepTimer,
              ),
            ],
          ),
          if (repeatMode == 'custom')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số lần lặp lại'),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    setState(() => customRepeatCount = parsed);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
