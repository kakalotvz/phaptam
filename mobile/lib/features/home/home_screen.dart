import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/network/paged_public_feed.dart';
import '../../shared/widgets/content_cards.dart';
import '../../shared/widgets/paged_list_footer.dart';
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
  Timer? _quoteRefreshTimer;

  @override
  void initState() {
    super.initState();
    _quoteRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(dailyQuotesProvider);
      ref.invalidate(quoteBackgroundsProvider);
    });
  }

  @override
  void dispose() {
    _quoteRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audios = ref.watch(audioListProvider);
    final videos = ref.watch(videoListProvider);
    final news = ref.watch(newsListProvider);
    final knowledge = ref.watch(knowledgeListProvider);
    final quotes = ref.watch(dailyQuotesProvider);
    final quoteBackgrounds = ref.watch(quoteBackgroundsProvider);
    final banners = ref.watch(homeBannersProvider);

    return RefreshIndicator(
      onRefresh: () => _refreshHomeContent(ref),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            toolbarHeight: 72,
            titleSpacing: 18,
            title: Text(
              'Pháp Tâm',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
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
                      : _DailyQuoteCard(
                          quote: items.first,
                          backgrounds: quoteBackgrounds.value ?? const [],
                        ),
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
                            onFavorite: () =>
                                _favoriteAudio(context, ref, items.first),
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
                            height: 276,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, index) => SizedBox(
                                width: 280,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () =>
                                      showVideoPlayer(context, items[index]),
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
                  data: (items) => _articlePreviewSection(
                    context: context,
                    title: 'Tin Phật giáo',
                    emptyLabel: 'Chưa có tin tức',
                    items: _sortNews(items, _NewsSortOrder.newest),
                    collectionTitle: 'Tin tức',
                    endpointPath: '/news',
                  ),
                  loading: () => const _EmptyCard(
                    icon: Icons.article_outlined,
                    label: 'Chưa có tin tức',
                  ),
                  error: (error, stackTrace) => const _EmptyCard(
                    icon: Icons.article_outlined,
                    label: 'Không tải được tin tức',
                  ),
                ),
                const SizedBox(height: 24),
                knowledge.when(
                  data: (items) => _articlePreviewSection(
                    context: context,
                    title: 'Kiến thức',
                    emptyLabel: 'Chưa có bài kiến thức',
                    items: _sortNews(items, _NewsSortOrder.newest),
                    collectionTitle: 'Kiến thức',
                    endpointPath: '/knowledge',
                  ),
                  loading: () => const _EmptyCard(
                    icon: Icons.menu_book_outlined,
                    label: 'Chưa có bài kiến thức',
                  ),
                  error: (error, stackTrace) => const _EmptyCard(
                    icon: Icons.menu_book_outlined,
                    label: 'Không tải được kiến thức',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _articlePreviewSection({
    required BuildContext context,
    required String title,
    required String emptyLabel,
    required List<NewsItem> items,
    required String collectionTitle,
    String? endpointPath,
  }) {
    if (items.isEmpty) {
      return _EmptyCard(icon: Icons.article_outlined, label: emptyLabel);
    }
    final previewItems = items.take(10).toList();
    return CalmSection(
      title: title,
      action: TextButton(
        onPressed: () => _openArticleCollection(
          context,
          collectionTitle,
          items,
          endpointPath,
        ),
        child: const Text('Xem thêm'),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openArticleCollection(
          context,
          collectionTitle,
          items,
          endpointPath,
        ),
        child: Column(
          children: [
            for (final item in previewItems) ...[
              _NewsListTile(
                item: item,
                onTap: () => _showNewsDetail(context, item),
                onShare: item.shareEnabled
                    ? () => _showShareSheet(context, item)
                    : null,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  void _openArticleCollection(
    BuildContext context,
    String title,
    List<NewsItem> items,
    String? endpointPath,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleCollectionScreen(
          title: title,
          items: items,
          endpointPath: endpointPath,
        ),
      ),
    );
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

  Future<void> _refreshHomeContent(WidgetRef ref) async {
    await refreshPublicContent(ref);
    await Future.wait([
      ref.refresh(audioListProvider.future),
      ref.refresh(videoListProvider.future),
      ref.refresh(newsListProvider.future),
      ref.refresh(knowledgeListProvider.future),
      ref.refresh(dailyQuotesProvider.future),
      ref.refresh(quoteBackgroundsProvider.future),
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

  Future<void> _favoriteAudio(
    BuildContext context,
    WidgetRef ref,
    AudioItem audio,
  ) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã thêm vào yêu thích')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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

class ArticleCollectionScreen extends StatefulWidget {
  const ArticleCollectionScreen({
    required this.title,
    this.items = const [],
    this.endpointPath,
    super.key,
  });

  final String title;
  final List<NewsItem> items;
  final String? endpointPath;

  @override
  State<ArticleCollectionScreen> createState() =>
      _ArticleCollectionScreenState();
}

class _ArticleCollectionScreenState extends State<ArticleCollectionScreen> {
  PagedPublicFeed<NewsItem>? _feed;
  ScrollController? _scrollController;
  String _query = '';
  String? _categoryFilter;
  String? _sourceFilter;
  _NewsSortOrder _sortOrder = _NewsSortOrder.newest;

  @override
  void initState() {
    super.initState();
    if (widget.endpointPath != null) {
      _feed = PagedPublicFeed<NewsItem>(
        path: widget.endpointPath!,
        fromJson: NewsItem.fromJson,
        isValid: (item) => item.title.trim().isNotEmpty,
      )..addListener(_onFeedChanged);
      _scrollController = ScrollController()..addListener(_handleScroll);
      unawaited(_feed!.loadInitial());
    }
  }

  @override
  void dispose() {
    _scrollController
      ?..removeListener(_handleScroll)
      ..dispose();
    _feed
      ?..removeListener(_onFeedChanged)
      ..dispose();
    super.dispose();
  }

  void _onFeedChanged() {
    if (mounted) setState(() {});
  }

  void _handleScroll() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_feed?.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceItems = _feed?.items ?? widget.items;
    if (_feed != null &&
        (_query.trim().isNotEmpty ||
            _categoryFilter != null ||
            _sourceFilter != null)) {
      unawaited(_feed!.ensureAllLoaded());
    }
    final visibleItems = _sortArticles(
      _filterArticles(sourceItems),
      _sortOrder,
    );
    final categories = sourceItems
        .map((item) => item.category)
        .toSet()
        .toList();
    final sources = sourceItems.map((item) => item.source).toSet().toList();
    final filterLabel = [?_categoryFilter, ?_sourceFilter].isEmpty
        ? 'Tất cả'
        : [?_categoryFilter, ?_sourceFilter].join(' • ');

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _feed?.refresh ?? () async {},
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
          children: [
            _NewsSearchControls(
              query: _query,
              filterLabel: filterLabel,
              sortOrder: _sortOrder,
              onQueryChanged: (value) {
                setState(() => _query = value);
                if (value.trim().isNotEmpty) {
                  unawaited(_feed?.ensureAllLoaded());
                }
              },
              onFilterPressed: () => _showFilterSheet(categories, sources),
              onSortChanged: (value) => setState(() => _sortOrder = value),
            ),
            const SizedBox(height: 18),
            if (_feed != null && _feed!.loadingInitial && !_feed!.initialized)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.article_outlined),
                  title: Text('Đang tải bài viết'),
                ),
              )
            else if (visibleItems.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.article_outlined),
                  title: Text('Không tìm thấy bài viết phù hợp'),
                ),
              ),
            for (final item in visibleItems) ...[
              _NewsListTile(
                item: item,
                onTap: () => _showArticleDetail(context, item),
                onShare: item.shareEnabled
                    ? () => _showShareSheet(context, item)
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            if ((_feed?.loadingMore ?? false) || (_feed?.loadingAll ?? false))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
            if ((_feed?.initialized ?? false) &&
                !(_feed?.hasMore ?? true) &&
                visibleItems.isNotEmpty)
              PagedListFooter(
                label: widget.title == 'Kiến thức'
                    ? 'Bạn đã xem hết bài kiến thức rồi.'
                    : 'Bạn đã xem hết bài viết rồi.',
              ),
          ],
        ),
      ),
    );
  }

  List<NewsItem> _filterArticles(List<NewsItem> items) {
    final query = _query.trim().toLowerCase();
    return items.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.source.toLowerCase().contains(query) ||
          item.summary.toLowerCase().contains(query) ||
          item.content.toLowerCase().contains(query);
      final matchesCategory =
          _categoryFilter == null || item.category == _categoryFilter;
      final matchesSource =
          _sourceFilter == null || item.source == _sourceFilter;
      return matchesQuery && matchesCategory && matchesSource;
    }).toList();
  }

  List<NewsItem> _sortArticles(List<NewsItem> items, _NewsSortOrder order) {
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

  void _showFilterSheet(List<String> categories, List<String> sources) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
                selected: _categoryFilter == null && _sourceFilter == null,
                onSelected: (_) {
                  setSheetState(() {
                    _categoryFilter = null;
                    _sourceFilter = null;
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
                      selected: _categoryFilter == category,
                      onSelected: (_) {
                        setSheetState(() {
                          _categoryFilter = _categoryFilter == category
                              ? null
                              : category;
                        });
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
                      selected: _sourceFilter == source,
                      onSelected: (_) {
                        setSheetState(() {
                          _sourceFilter = _sourceFilter == source
                              ? null
                              : source;
                        });
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

  void _showArticleDetail(BuildContext context, NewsItem item) {
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
                    label: const Text('Chia sẻ bài này'),
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

class _DailyQuoteCard extends StatefulWidget {
  const _DailyQuoteCard({required this.quote, required this.backgrounds});

  final DailyQuote quote;
  final List<QuoteBackground> backgrounds;

  @override
  State<_DailyQuoteCard> createState() => _DailyQuoteCardState();
}

class _DailyQuoteCardState extends State<_DailyQuoteCard> {
  static const _mediaChannel = MethodChannel('phaptam/media');
  var _capturing = false;

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
        child: InkWell(
          onTap: _copyQuote,
          child: Stack(
            children: [
              if (widget.quote.imageUrl != null &&
                  widget.quote.imageUrl!.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    widget.quote.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              if (widget.quote.imageUrl != null &&
                  widget.quote.imageUrl!.isNotEmpty)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .38),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 54, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote,
                      color: widget.quote.imageUrl == null
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.white,
                      size: 26,
                    ),
                    const SizedBox(height: 8),
                    RichContent(
                      content: widget.quote.content,
                      compact: true,
                      baseStyle: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(
                            height: 1.28,
                            fontWeight: FontWeight.w700,
                            color: widget.quote.imageUrl == null
                                ? null
                                : Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Trích dẫn hôm nay',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.quote.imageUrl == null
                            ? null
                            : Colors.white.withValues(alpha: .82),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_capturing)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: IconButton.filledTonal(
                    tooltip: 'Chia sẻ trích dẫn',
                    onPressed: _showShareOptions,
                    icon: const Icon(Icons.ios_share_outlined),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyQuote() async {
    await Clipboard.setData(ClipboardData(text: widget.quote.content));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã sao chép trích dẫn')));
  }

  Future<void> _showShareOptions() async {
    final choice = await showModalBottomSheet<_QuoteShareMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Chia sẻ dạng chữ'),
              onTap: () => Navigator.pop(context, _QuoteShareMode.text),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Chia sẻ bằng hình ảnh'),
              onTap: () => Navigator.pop(context, _QuoteShareMode.image),
            ),
          ],
        ),
      ),
    );
    if (choice == _QuoteShareMode.text) {
      unawaited(
        SharePlus.instance.share(
          ShareParams(
            text: '${widget.quote.content}\n\n(Chia sẻ từ ứng dụng Pháp Tâm)',
          ),
        ),
      );
    } else if (choice == _QuoteShareMode.image) {
      final background = await _pickQuoteBackground();
      if (background == null) return;
      await _shareQuoteImage(backgroundUrl: background.imageUrl);
    }
  }

  Future<_QuoteBackgroundSelection?> _pickQuoteBackground() {
    return showModalBottomSheet<_QuoteBackgroundSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final backgrounds = widget.backgrounds;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn ảnh nền',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Ngẫu nhiên'),
                  subtitle: Text(
                    backgrounds.isEmpty
                        ? 'Dùng nền mặc định của Pháp Tâm'
                        : 'Hệ thống tự chọn một ảnh nền trong danh sách',
                  ),
                  onTap: () => Navigator.pop(
                    context,
                    _QuoteBackgroundSelection.random(),
                  ),
                ),
                if (backgrounds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: math.min(
                      MediaQuery.sizeOf(context).height * .56,
                      420,
                    ),
                    child: GridView.builder(
                      itemCount: backgrounds.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 9 / 16,
                          ),
                      itemBuilder: (context, index) {
                        final item = backgrounds[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(
                            context,
                            _QuoteBackgroundSelection(imageUrl: item.imageUrl),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _CachedQuoteBackgroundThumb(
                              imageUrl: item.imageUrl,
                              loadBytes: _loadBackgroundBytes,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareQuoteImage({required String? backgroundUrl}) async {
    final imagePath = await _renderQuoteImage(backgroundUrl: backgroundUrl);
    if (imagePath == null) return;

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(imagePath)],
        text: 'Chia sẻ từ ứng dụng Pháp Tâm',
      ),
    );
    if (!mounted) return;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lưu ảnh?'),
        content: const Text('Bạn muốn lưu ảnh trích dẫn này về máy không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu ảnh'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      final saved = await _saveImageToGallery(imagePath);
      unawaited(File(imagePath).delete().catchError((_) => File(imagePath)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Đã lưu ảnh vào bộ sưu tập' : 'Không lưu được ảnh',
          ),
        ),
      );
    } else {
      unawaited(File(imagePath).delete().catchError((_) => File(imagePath)));
    }
  }

  Future<String?> _renderQuoteImage({required String? backgroundUrl}) async {
    try {
      setState(() => _capturing = true);
      final selectedBackgroundUrl = backgroundUrl ?? _randomBackgroundUrl();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1080, 1920);
      final rect = Offset.zero & size;
      final backgroundImage = selectedBackgroundUrl == null
          ? null
          : await _loadNetworkImage(selectedBackgroundUrl);
      final tone = backgroundImage == null
          ? _QuoteImageTone.fallback()
          : await _analyzeQuoteArea(backgroundImage, size);
      final style = _styleForQuoteTone(tone);

      if (backgroundImage == null) {
        final paint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F2DF), Color(0xFFFFF4DC), Color(0xFFC9D8C0)],
          ).createShader(rect);
        canvas.drawRect(rect, paint);
      } else {
        _drawCoverImage(canvas, backgroundImage, size);
        backgroundImage.dispose();
      }

      _drawAdaptiveScrim(canvas, rect, style);

      final quoteText = _plainQuoteText(widget.quote.content);
      final quoteParagraph = _buildFittingParagraph(
        quoteText,
        width: 840,
        maxHeight: 820,
        startFontSize: _quoteFontSize(quoteText),
        style: style,
      );
      _drawQuoteBlock(
        canvas,
        quoteText,
        paragraph: quoteParagraph,
        style: style,
        centerY: 850,
      );

      _drawCenteredParagraph(
        canvas,
        'Pháp Tâm',
        width: 840,
        top: 1688,
        fontSize: 42,
        height: 1.2,
        color: style.watermarkColor,
        fontWeight: FontWeight.w800,
      );
      _drawCenteredParagraph(
        canvas,
        'Ứng dụng nuôi dưỡng chánh niệm mỗi ngày',
        width: 840,
        top: 1748,
        fontSize: 28,
        height: 1.25,
        color: style.watermarkColor.withValues(alpha: .82),
        fontWeight: FontWeight.w500,
      );

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bytes = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      finalImage.dispose();
      if (bytes == null) return null;
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/phaptam_quote_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tạo được ảnh trích dẫn')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  String? _randomBackgroundUrl() {
    if (widget.backgrounds.isEmpty) return widget.quote.imageUrl;
    final index = math.Random().nextInt(widget.backgrounds.length);
    return widget.backgrounds[index].imageUrl;
  }

  Future<ui.Image?> _loadNetworkImage(String url) async {
    final data = await _loadBackgroundBytes(url);
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<Uint8List> _loadBackgroundBytes(String url) async {
    final file = await _backgroundCacheFile(url);
    if (await file.exists()) return file.readAsBytes();

    final data = await NetworkAssetBundle(Uri.parse(url)).load(url);
    final bytes = data.buffer.asUint8List();
    if (!await file.parent.exists()) await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  Future<File> _backgroundCacheFile(String url) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/quote_background_cache');
    var name = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    if (name.length > 124) {
      name = '${name.substring(0, 84)}_${name.substring(name.length - 36)}';
    }
    return File('${directory.path}/$name.img');
  }

  void _drawCoverImage(Canvas canvas, ui.Image image, Size size) {
    final input = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, input, size);
    final source = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & input,
    );
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(image, source, destination, Paint());
  }

  Future<_QuoteImageTone> _analyzeQuoteArea(
    ui.Image image,
    Size canvasSize,
  ) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return _QuoteImageTone.fallback();

    final source = _coverSourceRect(image, canvasSize);
    const quoteArea = Rect.fromLTWH(100, 440, 880, 920);
    var luminanceSum = 0.0;
    var luminanceSquareSum = 0.0;
    var saturationSum = 0.0;
    var samples = 0;

    for (var yStep = 0; yStep < 14; yStep += 1) {
      for (var xStep = 0; xStep < 10; xStep += 1) {
        final canvasX = quoteArea.left + quoteArea.width * (xStep + .5) / 10;
        final canvasY = quoteArea.top + quoteArea.height * (yStep + .5) / 14;
        final imageX = (source.left + canvasX / canvasSize.width * source.width)
            .clamp(0, image.width - 1)
            .round();
        final imageY =
            (source.top + canvasY / canvasSize.height * source.height)
                .clamp(0, image.height - 1)
                .round();
        final offset = (imageY * image.width + imageX) * 4;
        final red = bytes.getUint8(offset) / 255;
        final green = bytes.getUint8(offset + 1) / 255;
        final blue = bytes.getUint8(offset + 2) / 255;
        final luminance = .2126 * red + .7152 * green + .0722 * blue;
        final maxChannel = math.max(red, math.max(green, blue));
        final minChannel = math.min(red, math.min(green, blue));
        final saturation = maxChannel == 0
            ? 0.0
            : (maxChannel - minChannel) / maxChannel;
        luminanceSum += luminance;
        luminanceSquareSum += luminance * luminance;
        saturationSum += saturation;
        samples += 1;
      }
    }

    final average = luminanceSum / samples;
    final variance = math.max(
      0,
      luminanceSquareSum / samples - average * average,
    );
    return _QuoteImageTone(
      luminance: average,
      contrast: math.sqrt(variance),
      saturation: saturationSum / samples,
    );
  }

  Rect _coverSourceRect(ui.Image image, Size size) {
    final input = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, input, size);
    return Alignment.center.inscribe(fitted.source, Offset.zero & input);
  }

  _QuoteRenderStyle _styleForQuoteTone(_QuoteImageTone tone) {
    final isBright = tone.luminance >= .62;
    final isDark = tone.luminance <= .34;
    final busy = tone.contrast >= .18 || tone.saturation >= .42;

    if (isBright) {
      return _QuoteRenderStyle(
        quoteColor: const Color(0xFF2F241C),
        outlineColor: Colors.white.withValues(alpha: .70),
        shadowColor: Colors.white.withValues(alpha: .40),
        panelColor: busy
            ? const Color(0xFFF9F1DF).withValues(alpha: .78)
            : const Color(0xFFFFF8EA).withValues(alpha: .46),
        panelBorderColor: Colors.white.withValues(alpha: .50),
        scrimColor: const Color(0xFF3B2A1E).withValues(alpha: .08),
        bottomShade: const Color(0xFF2E241A).withValues(alpha: .28),
        metaColor: const Color(0xFF35291F).withValues(alpha: .78),
        watermarkColor: const Color(0xFF2F241C),
        usePanel: busy || tone.luminance > .72,
      );
    }

    if (isDark) {
      return _QuoteRenderStyle(
        quoteColor: Colors.white,
        outlineColor: Colors.black.withValues(alpha: .46),
        shadowColor: Colors.black.withValues(alpha: .70),
        panelColor: busy
            ? Colors.black.withValues(alpha: .22)
            : Colors.transparent,
        panelBorderColor: Colors.white.withValues(alpha: .14),
        scrimColor: Colors.black.withValues(alpha: .16),
        bottomShade: Colors.black.withValues(alpha: .38),
        metaColor: Colors.white.withValues(alpha: .82),
        watermarkColor: Colors.white,
        usePanel: busy,
      );
    }

    return _QuoteRenderStyle(
      quoteColor: Colors.white,
      outlineColor: Colors.black.withValues(alpha: .42),
      shadowColor: Colors.black.withValues(alpha: .62),
      panelColor: busy
          ? Colors.black.withValues(alpha: .24)
          : Colors.black.withValues(alpha: .12),
      panelBorderColor: Colors.white.withValues(alpha: .16),
      scrimColor: Colors.black.withValues(alpha: busy ? .24 : .18),
      bottomShade: Colors.black.withValues(alpha: .42),
      metaColor: Colors.white.withValues(alpha: .84),
      watermarkColor: Colors.white,
      usePanel: busy,
    );
  }

  void _drawAdaptiveScrim(Canvas canvas, Rect rect, _QuoteRenderStyle style) {
    canvas.drawRect(rect, Paint()..color = style.scrimColor);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, style.bottomShade],
        ).createShader(rect),
    );
  }

  void _drawCenteredParagraph(
    Canvas canvas,
    String text, {
    required double width,
    required double top,
    required double fontSize,
    required double height,
    required Color color,
    required FontWeight fontWeight,
    double letterSpacing = 0,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: TextAlign.center, height: height),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
            ),
          )
          ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(paragraph, Offset((1080 - width) / 2, top));
  }

  ui.Paragraph _buildFittingParagraph(
    String text, {
    required double width,
    required double maxHeight,
    required double startFontSize,
    required _QuoteRenderStyle style,
  }) {
    var fontSize = startFontSize;
    while (fontSize >= 38) {
      final paragraph = _quoteParagraph(
        text,
        width: width,
        fontSize: fontSize,
        color: style.quoteColor,
      );
      if (paragraph.height <= maxHeight) return paragraph;
      fontSize -= 2;
    }
    return _quoteParagraph(
      text,
      width: width,
      fontSize: fontSize,
      color: style.quoteColor,
    );
  }

  ui.Paragraph _quoteParagraph(
    String text, {
    required double width,
    required double fontSize,
    required Color color,
    Paint? foreground,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: TextAlign.center, height: 1.32),
          )
          ..pushStyle(
            ui.TextStyle(
              color: foreground == null ? color : null,
              foreground: foreground,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          )
          ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: width));
  }

  void _drawQuoteBlock(
    Canvas canvas,
    String text, {
    required ui.Paragraph paragraph,
    required _QuoteRenderStyle style,
    required double centerY,
  }) {
    const width = 840.0;
    final left = (1080 - width) / 2;
    final top = centerY - paragraph.height / 2;

    if (style.usePanel) {
      final panelRect = Rect.fromLTWH(
        left - 54,
        top - 74,
        width + 108,
        paragraph.height + 148,
      );
      final radius = Radius.circular(math.min(42, panelRect.height / 4));
      canvas.drawRRect(
        RRect.fromRectAndRadius(panelRect, radius),
        Paint()..color = style.panelColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(panelRect.deflate(1.5), radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = style.panelBorderColor,
      );
    }

    final fontSize = paragraphStyleFontSize(paragraph, text);
    final softShadowParagraph = _quoteParagraph(
      text,
      width: width,
      fontSize: fontSize,
      color: style.shadowColor,
    );
    final shadowParagraph = _quoteParagraph(
      text,
      width: width,
      fontSize: fontSize,
      color: style.quoteColor,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..color = style.outlineColor,
    );
    canvas.drawParagraph(softShadowParagraph, Offset(left, top + 8));
    canvas.drawParagraph(shadowParagraph, Offset(left, top + 2));
    canvas.drawParagraph(paragraph, Offset(left, top));
  }

  double paragraphStyleFontSize(ui.Paragraph paragraph, String text) {
    var fontSize = _quoteFontSize(text);
    while (fontSize >= 38) {
      final probe = _quoteParagraph(
        text,
        width: 840,
        fontSize: fontSize,
        color: Colors.white,
      );
      if ((probe.height - paragraph.height).abs() < 1) return fontSize;
      fontSize -= 2;
    }
    return fontSize;
  }

  double _quoteFontSize(String text) {
    if (text.length <= 70) return 70;
    if (text.length <= 120) return 60;
    if (text.length <= 190) return 52;
    return 46;
  }

  String _plainQuoteText(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\[[^\]]+\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<bool> _saveImageToGallery(String path) async {
    try {
      final result = await _mediaChannel.invokeMethod<bool>('saveImage', {
        'path': path,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}

enum _QuoteShareMode { text, image }

class _CachedQuoteBackgroundThumb extends StatelessWidget {
  const _CachedQuoteBackgroundThumb({
    required this.imageUrl,
    required this.loadBytes,
  });

  final String imageUrl;
  final Future<Uint8List> Function(String url) loadBytes;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: loadBytes(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: const Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}

class _QuoteBackgroundSelection {
  const _QuoteBackgroundSelection({required this.imageUrl});

  factory _QuoteBackgroundSelection.random() {
    return const _QuoteBackgroundSelection(imageUrl: null);
  }

  final String? imageUrl;
}

class _QuoteImageTone {
  const _QuoteImageTone({
    required this.luminance,
    required this.contrast,
    required this.saturation,
  });

  factory _QuoteImageTone.fallback() {
    return const _QuoteImageTone(
      luminance: .58,
      contrast: .12,
      saturation: .18,
    );
  }

  final double luminance;
  final double contrast;
  final double saturation;
}

class _QuoteRenderStyle {
  const _QuoteRenderStyle({
    required this.quoteColor,
    required this.outlineColor,
    required this.shadowColor,
    required this.panelColor,
    required this.panelBorderColor,
    required this.scrimColor,
    required this.bottomShade,
    required this.metaColor,
    required this.watermarkColor,
    required this.usePanel,
  });

  final Color quoteColor;
  final Color outlineColor;
  final Color shadowColor;
  final Color panelColor;
  final Color panelBorderColor;
  final Color scrimColor;
  final Color bottomShade;
  final Color metaColor;
  final Color watermarkColor;
  final bool usePanel;
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
