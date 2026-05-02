import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/offline/media_downloads.dart';
import '../../shared/widgets/content_cards.dart';
import '../../shared/widgets/media_download_button.dart';
import '../content/content_models.dart';
import '../content/content_providers.dart';

class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(audioCategoriesProvider);
    final selected = ref.watch(selectedAudioCategoryProvider);
    final audios = ref.watch(filteredAudioProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kinh Phật')),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LoadError(
          message: 'Chưa tải được danh mục audio',
          onRetry: () {
            ref.invalidate(audioCategoriesProvider);
            ref.invalidate(audioListProvider);
          },
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(audioCategoriesProvider);
            ref.invalidate(audioListProvider);
            await ref.read(audioListProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
            children: [
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final name = index == 0 ? 'Tất cả' : items[index - 1].name;
                    final isSelected = index == 0
                        ? selected == null
                        : selected == name;
                    return ChoiceChip(
                      label: Text(name),
                      selected: isSelected,
                      onSelected: (_) => ref
                          .read(selectedAudioCategoryProvider.notifier)
                          .select(index == 0 ? null : name),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              if (ref.watch(audioListProvider).isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (audios.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.library_music_outlined),
                    title: Text('Chưa có audio'),
                    subtitle: Text(
                      'Thêm audio trong admin để hiển thị tại đây.',
                    ),
                  ),
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Column(
                    key: ValueKey(selected ?? 'all'),
                    children: [
                      for (final audio in audios) ...[
                        AudioTile(
                          audio: audio,
                          onTap: () => _showPlayer(context, audio),
                          trailing: MediaDownloadButton(
                            mediaKey: mediaKey('audio', audio.id),
                            title: audio.title,
                            url: audio.audioUrl,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlayer(BuildContext context, AudioItem audio) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _AudioPlayerSheet(audio: audio),
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

class _AudioPlayerSheet extends ConsumerStatefulWidget {
  const _AudioPlayerSheet({required this.audio});

  final AudioItem audio;

  @override
  ConsumerState<_AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends ConsumerState<_AudioPlayerSheet> {
  late final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  double progress = .32;
  double speed = 1;
  String repeatMode = 'once';
  int customRepeatCount = 5;
  Duration? sleepTimer;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isPlaying = false;
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
    _player = AudioPlayer();
    _positionSub = _player.positionStream.listen((value) {
      if (!mounted) return;
      setState(() {
        position = value;
        progress = _progressValue(value, duration);
      });
    });
    _stateSub = _player.playerStateStream.listen((value) {
      if (!mounted) return;
      setState(() => isPlaying = value.playing);
    });
    unawaited(_loadAudio());
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    final audio = widget.audio;
    final source = await ref
        .read(mediaDownloadsProvider.notifier)
        .sourceFor(mediaKey('audio', audio.id), audio.audioUrl);
    final loadedDuration = source == audio.audioUrl
        ? await _player.setUrl(source)
        : await _player.setFilePath(source);
    await _player.setSpeed(speed);
    if (!mounted) return;
    setState(() {
      duration = loadedDuration ?? audio.duration;
      loading = false;
    });
  }

  Future<void> _togglePlayback() async {
    if (loading) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seekBy(Duration offset) async {
    final next = position + offset;
    await _player.seek(
      next < Duration.zero
          ? Duration.zero
          : next > duration
          ? duration
          : next,
    );
  }

  Future<void> _seekToProgress(double value) async {
    setState(() => progress = value);
    if (duration == Duration.zero) return;
    await _player.seek(
      Duration(milliseconds: (duration.inMilliseconds * value).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.audio;
    final downloads = ref
        .watch(mediaDownloadsProvider)
        .whenOrNull(data: (value) => value);
    final downloaded =
        downloads?.isDownloaded(mediaKey('audio', audio.id)) ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Hero(
            tag: 'audio-${audio.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.network(
                audio.thumbnailUrl,
                width: 180,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.music_note, size: 72),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            audio.title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            downloaded
                ? 'Đang ưu tiên bản đã tải về'
                : 'Dùng online, có thể tải về để nghe offline',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Slider(
            value: progress,
            onChanged: loading
                ? null
                : (value) => unawaited(_seekToProgress(value)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(position)),
              Text('-${_formatDuration(duration - position)}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: loading
                    ? null
                    : () => unawaited(_seekBy(const Duration(seconds: -10))),
                icon: const Icon(Icons.replay_10),
              ),
              const SizedBox(width: 18),
              IconButton.filled(
                onPressed: _togglePlayback,
                iconSize: 34,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 18),
              IconButton.filledTonal(
                onPressed: loading
                    ? null
                    : () => unawaited(_seekBy(const Duration(seconds: 10))),
                icon: const Icon(Icons.forward_10),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              PopupMenuButton<double>(
                onSelected: (value) {
                  setState(() => speed = value);
                  unawaited(_player.setSpeed(value));
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

double _progressValue(Duration position, Duration duration) {
  if (duration.inMilliseconds <= 0) return 0;
  return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
}

String _formatDuration(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}
