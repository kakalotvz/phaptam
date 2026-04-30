import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/widgets/content_cards.dart';
import '../content/content_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audios = ref.watch(audioListProvider);
    final videos = ref.watch(videoListProvider);
    final news = ref.watch(newsListProvider);

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('Phap Tam'),
          actions: [
            IconButton(
              tooltip: 'Thong bao',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          sliver: SliverList.list(
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: .94, end: 1),
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Binh an khong phai la noi khong co tieng dong, ma la tam khong bi keo di.',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Loi nhac hom nay',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CalmSection(
                title: 'Nghe tiep',
                child: AudioTile(audio: audios.first),
              ),
              const SizedBox(height: 24),
              CalmSection(
                title: 'Video noi bat',
                child: SizedBox(
                  height: 228,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: videos.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 14),
                    itemBuilder: (context, index) => SizedBox(
                      width: 280,
                      child: VideoCard(video: videos[index]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CalmSection(
                title: 'Tin Phat giao',
                child: Column(
                  children: [
                    for (final item in news)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.source} • ${DateFormat('dd/MM/yyyy').format(item.publishedAt)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
