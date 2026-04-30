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
      appBar: AppBar(title: const Text('Kinh Phat')),
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
                final name = index == 0 ? 'Tat ca' : categories[index - 1].name;
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
            'Tu dong tiep tuc tu vi tri da nghe',
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
          Row(
            children: [
              Expanded(child: Text('Toc do ${speed.toStringAsFixed(1)}x')),
              DropdownButton<double>(
                value: speed,
                items: const [
                  DropdownMenuItem(value: .75, child: Text('0.75x')),
                  DropdownMenuItem(value: 1, child: Text('1.0x')),
                  DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                  DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                ],
                onChanged: (value) => setState(() => speed = value ?? 1),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.bedtime_outlined),
                label: const Text('Hen gio'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
