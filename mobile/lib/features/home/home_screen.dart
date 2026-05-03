import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_client.dart';
import '../../shared/widgets/content_cards.dart';
import '../../shared/widgets/rich_content.dart';
import '../audio/audio_screen.dart';
import '../content/content_models.dart';
import '../content/content_providers.dart';
import '../video/video_screen.dart';

enum _NewsSortOrder { newest, oldest, popular }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _newsQuery = '';
  String? _newsCategoryFilter;
  String? _newsSourceFilter;
  _NewsSortOrder _newsSortOrder = _NewsSortOrder.newest;

  @override
  Widget build(BuildContext context) {
    final audios = ref.watch(audioListProvider);
    final videos = ref.watch(videoListProvider);
    final news = ref.watch(newsListProvider);
    final quotes = ref.watch(dailyQuotesProvider);
    final banners = ref.watch(homeBannersProvider);

    return RefreshIndicator(
      onRefresh: () => _refreshHomeContent(ref),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: const Text('Pháp Tâm'),
            actions: [
              IconButton(
                tooltip: 'Thông báo',
                onPressed: () {},
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverList.list(
              children: [
                quotes.when(
                  data: (items) => items.isEmpty
                      ? const _EmptyCard(
                          icon: Icons.notifications_none_outlined,
                          label: 'Không có lời nhắc hôm nay',
                        )
                      : _DailyQuoteCard(quote: items.first),
                  loading: () => const _EmptyCard(
                    icon: Icons.notifications_none_outlined,
                    label: 'Không có lời nhắc hôm nay',
                  ),
                  error: (error, stackTrace) => const _EmptyCard(
                    icon: Icons.notifications_none_outlined,
                    label: 'Không có lời nhắc hôm nay',
                  ),
                ),
                const SizedBox(height: 18),
                banners.when(
                  data: (items) => items.isEmpty
                      ? const SizedBox.shrink()
                      : _BannerStrip(banners: items),
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                audios.when(
                  data: (items) => items.isEmpty
                      ? const _EmptyCard(
                          icon: Icons.headphones_outlined,
                          label: 'Chưa có audio',
                        )
                      : CalmSection(
                          title: 'Nghe tiếp',
                          child: AudioTile(
                            audio: items.first,
                            onTap: () => showAudioPlayer(context, items.first),
                            onFavorite: () => _favoriteAudio(context, ref, items.first),
                          ),
                        ),
                  loading: () => const _EmptyCard(
                    icon: Icons.headphones_outlined,
                    label: 'Chưa có audio',
                  ),
                  error: (error, stackTrace) => const _EmptyCard(
                    icon: Icons.headphones_outlined,
                    label: 'Chưa có audio',
                  ),
                ),
                const SizedBox(height: 24),
                videos.when(
                  data: (items) => items.isEmpty
                      ? const _EmptyCard(
                          icon: Icons.play_circle_outline,
                          label: 'Chưa có videos',
                        )
                      : CalmSection(
                          title: 'Video nổi bật',
                          child: SizedBox(
                            height: 228,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, index) => SizedBox(
                                width: 280,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => showVideoPlayer(context, items[index]),
                                  child: VideoCard(video: items[index]),
                                ),
                              ),
                            ),
                          ),
                        ),
                  loading: () => const _EmptyCard(
                    icon: Icons.play_circle_outline,
                    label: 'Chưa có videos',
                  ),
                  error: (error, stackTrace) => const _EmptyCard(
                    icon: Icons.play_circle_outline,
                    label: 'Chưa có videos',
                  ),
                ),
                const SizedBox(height: 24),
                news.when(
                  data: (items) {
                    final visibleNews = _sortNews(
                      _filterNews(items),
                      _newsSortOrder,
                    );
                    final categories = items
                        .map((item) => item.category)
                        .toSet()
                        .toList();
                    final sources = items
                        .map((item) => item.source)
                        .toSet()
                        .toList();
                    return items.isEmpty
                        ? const _EmptyCard(
                            icon: Icons.article_outlined,
                            label: 'Chưa có tin tức',
                          )
                        : CalmSection(
                            title: 'Tin Phật giáo',
                            child: Column(
                              children: [
                                _NewsSearchControls(
                                  query: _newsQuery,
                                  filterLabel: _newsFilterLabel,
                                  sortOrder: _newsSortOrder,
                                  onQueryChanged: (value) =>
                                      setState(() => _newsQuery = value),
                                  onFilterPressed: () =>
                                      _showNewsFilterSheet(categories, sources),
                                  onSortChanged: (value) =>
                                      setState(() => _newsSortOrder = value),
                                ),
                                const SizedBox(height: 12),
                                if (visibleNews.isEmpty)
                                  const Card(
                                    child: ListTile(
                                      leading: Icon(Icons.article_outlined),
                                      title: Text('Chưa có tin tức'),
                                    ),
                                  ),
                                for (final item in visibleNews)
                                  _NewsListTile(
                                    item: item,
                                    onTap: () => _showNewsDetail(context, item),
                                    onShare: item.shareEnabled
                                        ? () => _showShareSheet(context, item)
                                        : null,
                                  ),
                              ],
                            ),
                          );
                  },
                  loading: () => const _EmptyCard(
                    icon: Icons.article_outlined,
                    label: 'Chưa có tin tức',
                  ),
                  error: (error, stackTrace) => const _EmptyCard(
                    icon: Icons.article_outlined,
                    label: 'Không tải được tin tức',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _newsFilterLabel {
    final parts = [?_newsCategoryFilter, ?_newsSourceFilter];
    return parts.isEmpty ? 'Tất cả' : parts.join(' • ');
  }

  List<NewsItem> _filterNews(List<NewsItem> items) {
    final query = _newsQuery.trim().toLowerCase();
    return items.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.source.toLowerCase().contains(query) ||
          item.summary.toLowerCase().contains(query) ||
          item.content.toLowerCase().contains(query);
      final matchesCategory =
          _newsCategoryFilter == null || item.category == _newsCategoryFilter;
      final matchesSource =
          _newsSourceFilter == null || item.source == _newsSourceFilter;
      return matchesQuery && matchesCategory && matchesSource;
    }).toList();
  }

  List<NewsItem> _sortNews(List<NewsItem> items, _NewsSortOrder order) {
    final sorted = [...items];
    sorted.sort((a, b) {
      return switch (order) {
        _NewsSortOrder.oldest => a.publishedAt.compareTo(b.publishedAt),
        _NewsSortOrder.popular => b.viewCount.compareTo(a.viewCount),
        _NewsSortOrder.newest => b.publishedAt.compareTo(a.publishedAt),
      };
    });
    return sorted;
  }

  void _showNewsFilterSheet(List<String> categories, List<String> sources) {
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
              FilterChip(
                label: const Text('Tất cả'),
                selected:
                    _newsCategoryFilter == null && _newsSourceFilter == null,
                onSelected: (_) {
                  setSheetState(() {
                    _newsCategoryFilter = null;
                    _newsSourceFilter = null;
                  });
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              Text('Danh mục', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in categories)
                    FilterChip(
                      label: Text(category),
                      selected: _newsCategoryFilter == category,
                      onSelected: (_) {
                        setSheetState(
                          () => _newsCategoryFilter =
                              _newsCategoryFilter == category ? null : category,
                        );
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Nguồn', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final source in sources)
                    FilterChip(
                      label: Text(source),
                      selected: _newsSourceFilter == source,
                      onSelected: (_) {
                        setSheetState(
                          () => _newsSourceFilter = _newsSourceFilter == source
                              ? null
                              : source,
                        );
                        setState(() {});
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshHomeContent(WidgetRef ref) async {
    refreshPublicContent(ref);
    await Future.wait([
      ref.refresh(audioListProvider.future),
      ref.refresh(videoListProvider.future),
      ref.refresh(newsListProvider.future),
      ref.refresh(dailyQuotesProvider.future),
      ref.refresh(homeBannersProvider.future),
    ]);
  }

  void _showNewsDetail(BuildContext context, NewsItem item) {
    unawaited(apiClient.post('/news/${item.id}/view', {}));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .78,
          maxChildSize: .94,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                if (item.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      item.imageUrl!,
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.category} • ${DateFormat('dd/MM/yyyy').format(item.publishedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                if (item.summary.trim().isNotEmpty)
                  Text(
                    item.summary,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 14),
                RichContent(content: item.content),
                if (item.shareEnabled) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _showShareSheet(context, item),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Chia sẻ tin này'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  void _showShareSheet(BuildContext context, NewsItem item) {
    final link = item.link ?? 'Pháp Tâm - ${item.title}';
    unawaited(
      SharePlus.instance.share(
        ShareParams(
          text: '${item.title}\n$link\n\nChia sẻ từ ứng dụng Pháp Tâm',
          subject: item.title,
        ),
      ),
    );
  }

  Future<void> _favoriteAudio(BuildContext context, WidgetRef ref, AudioItem audio) async {
    if (!ref.read(isLoggedInProvider)) {
      context.push('/login');
      return;
    }
    try {
      await apiClient.post('/favorites', {
        'type': 'AUDIO',
        'contentId': audio.id,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm vào yêu thích')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(leading: Icon(icon), title: Text(label)),
    );
  }
}

class _NewsListTile extends StatelessWidget {
  const _NewsListTile({
    required this.item,
    required this.onTap,
    required this.onShare,
  });

  final NewsItem item;
  final VoidCallback onTap;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.category} • ${item.source} • ${DateFormat('dd/MM/yyyy').format(item.publishedAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (onShare != null) ...[
                      const SizedBox(height: 8),
                      IconButton(
                        tooltip: 'Chia sẻ',
                        visualDensity: VisualDensity.compact,
                        onPressed: onShare,
                        icon: const Icon(Icons.share_outlined),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: imageUrl == null || imageUrl.trim().isEmpty
                    ? Container(
                        width: 92,
                        height: 92,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: const Icon(Icons.article_outlined),
                      )
                    : Image.network(
                        imageUrl,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 92,
                          height: 92,
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          child: const Icon(Icons.article_outlined),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsSearchControls extends StatelessWidget {
  const _NewsSearchControls({
    required this.query,
    required this.filterLabel,
    required this.sortOrder,
    required this.onQueryChanged,
    required this.onFilterPressed,
    required this.onSortChanged,
  });

  final String query;
  final String filterLabel;
  final _NewsSortOrder sortOrder;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onFilterPressed;
  final ValueChanged<_NewsSortOrder> onSortChanged;

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
                  hintText: 'Tìm kiếm tin tức',
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
            DropdownButton<_NewsSortOrder>(
              value: sortOrder,
              underline: const SizedBox.shrink(),
              onChanged: (value) {
                if (value != null) onSortChanged(value);
              },
              items: const [
                DropdownMenuItem(
                  value: _NewsSortOrder.newest,
                  child: Text('Mới -> cũ'),
                ),
                DropdownMenuItem(
                  value: _NewsSortOrder.oldest,
                  child: Text('Cũ -> mới'),
                ),
                DropdownMenuItem(
                  value: _NewsSortOrder.popular,
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

class _DailyQuoteCard extends StatelessWidget {
  const _DailyQuoteCard({required this.quote});

  final DailyQuote quote;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: .94, end: 1),
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (quote.imageUrl != null && quote.imageUrl!.isNotEmpty)
              Positioned.fill(
                child: Image.network(quote.imageUrl!, fit: BoxFit.cover),
              ),
            if (quote.imageUrl != null && quote.imageUrl!.isNotEmpty)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .38),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote,
                    color: quote.imageUrl == null
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  RichContent(
                    content: quote.content,
                    compact: true,
                    baseStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                      height: 1.34,
                      fontWeight: FontWeight.w700,
                      color: quote.imageUrl == null ? null : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Lời nhắc hôm nay',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: quote.imageUrl == null
                          ? null
                          : Colors.white.withValues(alpha: .82),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerStrip extends StatelessWidget {
  const _BannerStrip({required this.banners});

  final List<HomeBanner> banners;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: banners.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final banner = banners[index];
          return SizedBox(
            width: MediaQuery.sizeOf(context).width - 48,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: banner.link == null || banner.link!.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: banner.link!),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép liên kết banner'),
                            ),
                          );
                        }
                      },
                child: Image.network(
                  banner.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
