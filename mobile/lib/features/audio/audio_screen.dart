import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/content_cards.dart';
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final name = index == 0 ? 'Tất cả' : categories[index - 1].name;
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Column(
              key: ValueKey(selected ?? 'all'),
              children: [
                for (final audio in audios) ...[
                  AudioTile(
                    audio: audio,
                    onTap: () => _showPlayer(context, audio),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
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

class _AudioPlayerSheet extends StatefulWidget {
  const _AudioPlayerSheet({required this.audio});

  final AudioItem audio;

  @override
  State<_AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<_AudioPlayerSheet> {
  double progress = .32;
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
                  onTap: () => Navigator.pop(context, Duration(minutes: minutes)),
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
    final audio = widget.audio;
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
            'Tự động tiếp tục từ vị trí đã nghe',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Slider(
            value: progress,
            onChanged: (value) => setState(() => progress = value),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [Text('13:24'), Text('-28:54')],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.replay_10),
              ),
              const SizedBox(width: 18),
              IconButton.filled(
                onPressed: () {},
                iconSize: 34,
                icon: const Icon(Icons.play_arrow),
              ),
              const SizedBox(width: 18),
              IconButton.filledTonal(
                onPressed: () {},
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
                onSelected: (value) => setState(() => speed = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: .75, child: Text('Tốc độ 0.75x')),
                  PopupMenuItem(value: 1, child: Text('Tốc độ 1.0x')),
                  PopupMenuItem(value: 1.25, child: Text('Tốc độ 1.25x')),
                  PopupMenuItem(value: 1.5, child: Text('Tốc độ 1.5x')),
                ],
                child: Chip(
                  avatar: const Icon(Icons.speed, size: 18),
                  label: Text('Tốc độ ${speed.toStringAsFixed(speed == 1 ? 1 : 2)}x'),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => setState(() => repeatMode = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'once', child: Text('Lặp lại 1 lần')),
                  PopupMenuItem(value: 'three', child: Text('Lặp lại 3 lần')),
                  PopupMenuItem(value: 'forever', child: Text('Lặp lại liên tục')),
                  PopupMenuItem(value: 'custom', child: Text('Tùy chỉnh')),
                ],
                child: Chip(
                  avatar: const Icon(Icons.repeat, size: 18),
                  label: Text(repeatLabel),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.bedtime_outlined, size: 18),
                label: Text(sleepTimer == null ? 'Hẹn giờ' : '${sleepTimer!.inMinutes} phút'),
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
