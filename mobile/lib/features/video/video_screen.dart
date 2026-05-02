import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/media_downloads.dart';
import '../../shared/widgets/content_cards.dart';
import '../../shared/widgets/media_download_button.dart';
import '../content/content_models.dart';
import '../content/content_providers.dart';

enum _VideoSortOrder { newest, oldest, popular }

class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  String _query = '';
  String? _teacherFilter;
  String? _topicFilter;
  _VideoSortOrder _sortOrder = _VideoSortOrder.newest;

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(videoListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pháp thoại')),
      body: videos.when(
        loading: () => const _EmptyVideoList(),
        error: (error, stackTrace) => const _EmptyVideoList(),
        data: (items) {
          final teachers = items
              .map((e) => e.teacher)
              .where((teacher) => teacher.trim().isNotEmpty)
              .toSet()
              .toList();
          final topics = items
              .map((e) => e.topic)
              .where((topic) => topic.trim().isNotEmpty)
              .toSet()
              .toList();
          final visibleItems = _sortVideos(_filterVideos(items), _sortOrder);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(videoListProvider);
              await ref.read(videoListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                _VideoSearchControls(
                  query: _query,
                  filterLabel: _filterLabel,
                  sortOrder: _sortOrder,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onFilterPressed: () => _showFilterSheet(teachers, topics),
                  onSortChanged: (value) => setState(() => _sortOrder = value),
                ),
                const SizedBox(height: 14),
                if (visibleItems.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.video_library_outlined),
                      title: Text('Chưa có videos'),
                    ),
                  ),
                for (final video in visibleItems) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _showVideoPlayer(context, video),
                    child: VideoCard(
                      video: video,
                      action: _isDirectVideoUrl(video.videoUrl)
                          ? MediaDownloadButton(
                              mediaKey: mediaKey('video', video.id),
                              title: video.title,
                              url: video.videoUrl,
                            )
                          : null,
                    ),
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

  String get _filterLabel {
    final parts = [?_teacherFilter, ?_topicFilter];
    return parts.isEmpty ? 'Tất cả' : parts.join(' • ');
  }

  List<VideoItem> _filterVideos(List<VideoItem> items) {
    final query = _query.trim().toLowerCase();
    return items.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.teacher.toLowerCase().contains(query) ||
          item.topic.toLowerCase().contains(query) ||
          (item.description ?? '').toLowerCase().contains(query);
      final matchesTeacher =
          _teacherFilter == null || item.teacher == _teacherFilter;
      final matchesTopic = _topicFilter == null || item.topic == _topicFilter;
      return matchesQuery && matchesTeacher && matchesTopic;
    }).toList();
  }

  List<VideoItem> _sortVideos(List<VideoItem> items, _VideoSortOrder order) {
    final sorted = [...items];
    sorted.sort((a, b) {
      return switch (order) {
        _VideoSortOrder.oldest => a.createdAt.compareTo(b.createdAt),
        _VideoSortOrder.popular => b.viewCount.compareTo(a.viewCount),
        _VideoSortOrder.newest => b.createdAt.compareTo(a.createdAt),
      };
    });
    return sorted;
  }

  void _showFilterSheet(List<String> teachers, List<String> topics) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            shrinkWrap: true,
            children: [
              Text('Bộ lọc', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Tất cả'),
                    selected: _teacherFilter == null && _topicFilter == null,
                    onSelected: (_) {
                      setSheetState(() {
                        _teacherFilter = null;
                        _topicFilter = null;
                      });
                      setState(() {});
                    },
                  ),
                  for (final teacher in teachers)
                    FilterChip(
                      label: Text(teacher),
                      selected: _teacherFilter == teacher,
                      onSelected: (_) {
                        setSheetState(
                          () => _teacherFilter = _teacherFilter == teacher
                              ? null
                              : teacher,
                        );
                        setState(() {});
                      },
                    ),
                ],
              ),
              if (topics.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Danh mục',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final topic in topics)
                      FilterChip(
                        label: Text(topic),
                        selected: _topicFilter == topic,
                        onSelected: (_) {
                          setSheetState(
                            () => _topicFilter = _topicFilter == topic
                                ? null
                                : topic,
                          );
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showVideoPlayer(BuildContext context, VideoItem video) {
    unawaited(apiClient.post('/video/${video.id}/view', {}));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _VideoPlayerSheet(video: video),
    );
  }
}

class _VideoSearchControls extends StatelessWidget {
  const _VideoSearchControls({
    required this.query,
    required this.filterLabel,
    required this.sortOrder,
    required this.onQueryChanged,
    required this.onFilterPressed,
    required this.onSortChanged,
  });

  final String query;
  final String filterLabel;
  final _VideoSortOrder sortOrder;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onFilterPressed;
  final ValueChanged<_VideoSortOrder> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm kiếm video',
                ),
                onChanged: onQueryChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Bộ lọc',
              onPressed: onFilterPressed,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Bộ lọc: $filterLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            DropdownButton<_VideoSortOrder>(
              value: sortOrder,
              underline: const SizedBox.shrink(),
              onChanged: (value) {
                if (value != null) onSortChanged(value);
              },
              items: const [
                DropdownMenuItem(
                  value: _VideoSortOrder.newest,
                  child: Text('Mới -> cũ'),
                ),
                DropdownMenuItem(
                  value: _VideoSortOrder.oldest,
                  child: Text('Cũ -> mới'),
                ),
                DropdownMenuItem(
                  value: _VideoSortOrder.popular,
                  child: Text('Nhiều lượt xem'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyVideoList extends StatelessWidget {
  const _EmptyVideoList();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.video_library_outlined),
            title: Text('Chưa có videos'),
          ),
        ),
      ],
    );
  }
}

class _VideoPlayerSheet extends ConsumerStatefulWidget {
  const _VideoPlayerSheet({required this.video});

  final VideoItem video;

  @override
  ConsumerState<_VideoPlayerSheet> createState() => _VideoPlayerSheetState();
}

class _VideoPlayerSheetState extends ConsumerState<_VideoPlayerSheet> {
  double speed = 1;
  String repeatMode = 'once';
  int customRepeatCount = 5;
  Duration? sleepTimer;
  VideoPlayerController? controller;
  bool loading = true;

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
  void initState() {
    super.initState();
    if (_isDirectVideoUrl(widget.video.videoUrl)) {
      unawaited(_loadVideo());
    } else {
      loading = false;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    final video = widget.video;
    final source = await ref
        .read(mediaDownloadsProvider.notifier)
        .sourceFor(mediaKey('video', video.id), video.videoUrl);
    final nextController = source == video.videoUrl
        ? VideoPlayerController.networkUrl(Uri.parse(source))
        : VideoPlayerController.file(File(source));
    await nextController.initialize();
    await nextController.setPlaybackSpeed(speed);
    if (!mounted) {
      await nextController.dispose();
      return;
    }
    setState(() {
      controller = nextController;
      loading = false;
    });
  }

  Future<void> _togglePlayback() async {
    final player = controller;
    if (player == null || loading) return;
    if (player.value.isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final downloads = ref
        .watch(mediaDownloadsProvider)
        .whenOrNull(data: (value) => value);
    final downloaded =
        downloads?.isDownloaded(mediaKey('video', video.id)) ?? false;
    final player = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: player != null && player.value.isInitialized
                  ? VideoPlayer(player)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(Icons.play_circle_outline),
                              ),
                        ),
                        if (loading)
                          const Center(child: CircularProgressIndicator()),
                      ],
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
          Text(
            downloaded
                ? '${video.teacher} • ${video.topic} • Bản offline'
                : '${video.teacher} • ${video.topic}',
          ),
          const SizedBox(height: 18),
          IconButton.filled(
            onPressed: _isDirectVideoUrl(video.videoUrl)
                ? _togglePlayback
                : null,
            iconSize: 34,
            icon: Icon(
              player?.value.isPlaying == true ? Icons.pause : Icons.play_arrow,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              PopupMenuButton<double>(
                onSelected: (value) {
                  setState(() => speed = value);
                  unawaited(controller?.setPlaybackSpeed(value));
                },
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

bool _isDirectVideoUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  return path.endsWith('.mp4');
}
