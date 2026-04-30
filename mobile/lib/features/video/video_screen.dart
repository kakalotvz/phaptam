import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/content_cards.dart';
import '../content/content_providers.dart';

class VideoScreen extends ConsumerWidget {
  const VideoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(videoListProvider);
    final teachers = videos.map((e) => e.teacher).toSet().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Pháp thoại')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
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
              FilterChip(
                label: const Text('Chủ đề'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final video in videos) ...[
            VideoCard(video: video),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
