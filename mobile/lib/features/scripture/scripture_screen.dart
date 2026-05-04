import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../shared/widgets/rich_content.dart';
import '../content/content_models.dart';
import '../content/content_providers.dart';

class ScriptureScreen extends ConsumerWidget {
  const ScriptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripturesAsync = ref.watch(scriptureListProvider);
    final remindersAsync = ref.watch(scriptureReminderProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tụng kinh')),
      body: scripturesAsync.when(
        loading: () => _ScriptureContent(
          scriptures: const [],
          remindersAsync: remindersAsync,
          isLoggedIn: isLoggedIn,
          ref: ref,
        ),
        error: (error, _) => _ScriptureContent(
          scriptures: const [],
          remindersAsync: remindersAsync,
          isLoggedIn: isLoggedIn,
          ref: ref,
        ),
        data: (scriptures) => RefreshIndicator(
          onRefresh: () async {
            await refreshPublicContent(ref);
            await ref.read(scriptureListProvider.future);
          },
          child: _ScriptureContent(
            scriptures: scriptures,
            remindersAsync: remindersAsync,
            isLoggedIn: isLoggedIn,
            ref: ref,
          ),
        ),
      ),
    );
  }

  void _showReminderSheet(
    BuildContext context,
    WidgetRef ref,
    List<Scripture> scriptures,
  ) {
    var selected = scriptures.first;
    var title = 'Nhắc tụng ${selected.title}';
    var time = const TimeOfDay(hour: 5, minute: 30);
    var weekdays = <int>{1, 2, 3, 4, 5, 6, 7};
    var resumeMode = ReminderResumeMode.resume;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lịch nhắc tụng kinh',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: TextEditingController(text: title),
                    decoration: const InputDecoration(
                      labelText: 'Tên lời nhắc',
                    ),
                    onChanged: (value) => title = value,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Scripture>(
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Bộ kinh'),
                    items: [
                      for (final scripture in scriptures)
                        DropdownMenuItem(
                          value: scripture,
                          child: Text(scripture.title),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        selected = value;
                        title = 'Nhắc tụng ${value.title}';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(
                      _formatTime(
                        Duration(hours: time.hour, minutes: time.minute),
                      ),
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: time,
                      );
                      if (picked != null) setSheetState(() => time = picked);
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final day in const [
                        [1, 'T2'],
                        [2, 'T3'],
                        [3, 'T4'],
                        [4, 'T5'],
                        [5, 'T6'],
                        [6, 'T7'],
                        [7, 'CN'],
                      ])
                        FilterChip(
                          label: Text(day[1] as String),
                          selected: weekdays.contains(day[0]),
                          onSelected: (_) {
                            setSheetState(() {
                              final value = day[0] as int;
                              weekdays = weekdays.contains(value)
                                  ? ({...weekdays}..remove(value))
                                  : {...weekdays, value};
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ReminderResumeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ReminderResumeMode.resume,
                        icon: Icon(Icons.play_circle_outline),
                        label: Text('Tiếp tục'),
                      ),
                      ButtonSegment(
                        value: ReminderResumeMode.restart,
                        icon: Icon(Icons.restart_alt),
                        label: Text('Từ đầu'),
                      ),
                    ],
                    selected: {resumeMode},
                    onSelectionChanged: (value) =>
                        setSheetState(() => resumeMode = value.first),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Lưu lịch nhắc'),
                      onPressed: weekdays.isEmpty
                          ? null
                          : () async {
                              await ref
                                  .read(scriptureReminderProvider.notifier)
                                  .add(
                                    title: title.trim().isEmpty
                                        ? 'Nhắc tụng kinh'
                                        : title.trim(),
                                    scripture: selected,
                                    timeOfDay: Duration(
                                      hours: time.hour,
                                      minutes: time.minute,
                                    ),
                                    weekdays: weekdays,
                                    resumeMode: resumeMode,
                                  );
                              if (context.mounted) Navigator.pop(context);
                            },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

enum _ScriptureSortOrder { newest, oldest, popular }

class _ScriptureContent extends StatefulWidget {
  const _ScriptureContent({
    required this.scriptures,
    required this.remindersAsync,
    required this.isLoggedIn,
    required this.ref,
  });

  final List<Scripture> scriptures;
  final AsyncValue<List<ScriptureReminder>> remindersAsync;
  final bool isLoggedIn;
  final WidgetRef ref;

  @override
  State<_ScriptureContent> createState() => _ScriptureContentState();
}

class _ScriptureContentState extends State<_ScriptureContent> {
  String _query = '';
  String? _categoryFilter;
  _ScriptureSortOrder _sortOrder = _ScriptureSortOrder.newest;

  @override
  Widget build(BuildContext context) {
    final visibleScriptures = _sortScriptures(
      _filterScriptures(widget.scriptures),
      _sortOrder,
    );
    final scriptureGroups = _groupScriptures(visibleScriptures);
    final categories = widget.scriptures
        .map((item) => item.categoryParent ?? item.category ?? item.title)
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        FilledButton.icon(
          onPressed: widget.scriptures.isEmpty
              ? null
              : () {
                  if (!widget.isLoggedIn) {
                    context.push('/login');
                    return;
                  }
                  const ScriptureScreen()._showReminderSheet(
                    context,
                    widget.ref,
                    widget.scriptures,
                  );
                },
          icon: const Icon(Icons.add_alarm),
          label: const Text('Đặt lịch nhắc tụng kinh'),
        ),
        const SizedBox(height: 16),
        Text('Lịch nhắc', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (!widget.isLoggedIn)
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Không có lịch nhắc'),
              subtitle: const Text('Đăng nhập để đồng bộ lịch tụng kinh.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/login'),
            ),
          )
        else
          widget.remindersAsync.when(
            loading: () => const _EmptyReminderCard(),
            error: (error, stackTrace) => const _EmptyReminderCard(),
            data: (reminders) => Column(
              children: [
                if (reminders.isEmpty) const _EmptyReminderCard(),
                for (final reminder in reminders)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text(reminder.title),
                      subtitle: Text(
                        '${_formatTime(reminder.timeOfDay)} • ${reminder.scripture.title}\n${_formatWeekdays(reminder.weekdays)} • ${reminder.resumeMode == ReminderResumeMode.resume ? 'Tiếp tục chỗ dừng' : 'Bắt đầu lại'}',
                      ),
                      isThreeLine: true,
                      trailing: Switch(
                        value: reminder.active,
                        onChanged: (value) => widget.ref
                            .read(scriptureReminderProvider.notifier)
                            .toggle(reminder.id, value),
                      ),
                      onTap: () {
                        final startIndex =
                            reminder.resumeMode == ReminderResumeMode.resume
                            ? reminder.lastLineIndex
                            : 0;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ScriptureReader(
                              scripture: reminder.scripture,
                              reminderId: reminder.id,
                              initialLineIndex: startIndex,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text('Bộ kinh', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        _ScriptureSearchControls(
          query: _query,
          filterLabel: _categoryFilter ?? 'Tất cả',
          sortOrder: _sortOrder,
          onQueryChanged: (value) => setState(() => _query = value),
          onFilterPressed: () => _showFilterSheet(categories),
          onSortChanged: (value) => setState(() => _sortOrder = value),
        ),
        const SizedBox(height: 12),
        if (visibleScriptures.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.menu_book_outlined),
              title: Text('Chưa có bản Kinh tụng'),
            ),
          ),
        for (final group in scriptureGroups) ...[
          _ScriptureGroupCard(group: group),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<Scripture> _filterScriptures(List<Scripture> items) {
    final query = _query.trim().toLowerCase();
    return items.where((item) {
      final category = item.category ?? '';
      final parentCategory = item.categoryParent ?? '';
      final matchesQuery =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          category.toLowerCase().contains(query) ||
          parentCategory.toLowerCase().contains(query) ||
          (item.description ?? '').toLowerCase().contains(query);
      final matchesCategory =
          _categoryFilter == null ||
          category == _categoryFilter ||
          parentCategory == _categoryFilter ||
          item.title == _categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  List<Scripture> _sortScriptures(
    List<Scripture> items,
    _ScriptureSortOrder order,
  ) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return switch (order) {
        _ScriptureSortOrder.oldest => aDate.compareTo(bDate),
        _ScriptureSortOrder.popular => b.viewCount.compareTo(a.viewCount),
        _ScriptureSortOrder.newest => bDate.compareTo(aDate),
      };
    });
    return sorted;
  }

  void _showFilterSheet(List<String> categories) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            runSpacing: 10,
            children: [
              Text('Bộ lọc', style: Theme.of(context).textTheme.titleLarge),
              ListTile(
                leading: const Icon(Icons.clear_all),
                title: const Text('Tất cả danh mục'),
                selected: _categoryFilter == null,
                onTap: () {
                  setState(() => _categoryFilter = null);
                  Navigator.pop(context);
                },
              ),
              for (final category in categories)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(category),
                  selected: _categoryFilter == category,
                  onTap: () {
                    setState(() => _categoryFilter = category);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScriptureSearchControls extends StatelessWidget {
  const _ScriptureSearchControls({
    required this.query,
    required this.filterLabel,
    required this.sortOrder,
    required this.onQueryChanged,
    required this.onFilterPressed,
    required this.onSortChanged,
  });

  final String query;
  final String filterLabel;
  final _ScriptureSortOrder sortOrder;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onFilterPressed;
  final ValueChanged<_ScriptureSortOrder> onSortChanged;

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
                  hintText: 'Tìm kiếm bản tụng',
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
            DropdownButton<_ScriptureSortOrder>(
              value: sortOrder,
              underline: const SizedBox.shrink(),
              onChanged: (value) {
                if (value != null) onSortChanged(value);
              },
              items: const [
                DropdownMenuItem(
                  value: _ScriptureSortOrder.newest,
                  child: Text('Mới -> cũ'),
                ),
                DropdownMenuItem(
                  value: _ScriptureSortOrder.oldest,
                  child: Text('Cũ -> mới'),
                ),
                DropdownMenuItem(
                  value: _ScriptureSortOrder.popular,
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

class _ScriptureGroup {
  const _ScriptureGroup({required this.title, required this.items});

  final String title;
  final List<Scripture> items;
}

List<_ScriptureGroup> _groupScriptures(List<Scripture> scriptures) {
  final grouped = <String, List<Scripture>>{};
  for (final scripture in scriptures) {
    final title = (scripture.categoryParent?.trim().isNotEmpty ?? false)
        ? scripture.categoryParent!.trim()
        : (scripture.category?.trim().isNotEmpty ?? false)
        ? scripture.category!.trim()
        : scripture.title.trim();
    grouped.putIfAbsent(title, () => []).add(scripture);
  }
  return [
    for (final entry in grouped.entries)
      _ScriptureGroup(title: entry.key, items: entry.value),
  ];
}

class _ScriptureGroupCard extends StatelessWidget {
  const _ScriptureGroupCard({required this.group});

  final _ScriptureGroup group;

  @override
  Widget build(BuildContext context) {
    final shouldOpenSubcategory =
        group.items.any(
          (item) => item.categoryParent?.trim().isNotEmpty == true,
        ) ||
        group.items.length > 1 ||
        ((group.items.first.category?.trim().isNotEmpty ?? false) &&
            group.items.first.title.trim() != group.title);
    if (!shouldOpenSubcategory) {
      return _ScriptureListCard(
        scripture: group.items.first,
        sequence: group.items,
      );
    }

    final sortedItems = naturalSortScriptures(group.items);
    final totalLines = group.items.fold<int>(
      0,
      (sum, scripture) => sum + scripture.lines.length,
    );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(group.title),
        subtitle: Text('${group.items.length} phẩm • $totalLines dòng'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ScriptureCategoryScreen(
              title: group.title,
              items: sortedItems,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScriptureListCard extends StatelessWidget {
  const _ScriptureListCard({
    required this.scripture,
    required this.sequence,
    this.sequenceIndex = 0,
  });

  final Scripture scripture;
  final List<Scripture> sequence;
  final int sequenceIndex;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(
          scripture.categoryParent != null
              ? scripture.category ?? scripture.title
              : scripture.title,
        ),
        subtitle: Text(
          scripture.lines.isEmpty
              ? 'Chưa có dòng kinh'
              : scripture.categoryParent != null
              ? '${scripture.title} • ${scripture.lines.length} dòng'
              : scripture.description ?? '${scripture.lines.length} dòng',
        ),
        isThreeLine: scripture.lines.isNotEmpty,
        trailing: scripture.lines.isEmpty
            ? const Icon(Icons.info_outline)
            : const Icon(Icons.chevron_right),
        onTap: scripture.lines.isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ScriptureReader(
                    scripture: scripture,
                    chapterSequence: sequence,
                    chapterIndex: sequenceIndex,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ScriptureCategoryScreen extends StatelessWidget {
  const _ScriptureCategoryScreen({required this.title, required this.items});

  final String title;
  final List<Scripture> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          for (final entry in items.indexed) ...[
            _ScriptureListCard(
              scripture: entry.$2,
              sequence: items,
              sequenceIndex: entry.$1,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

List<Scripture> naturalSortScriptures(List<Scripture> items) {
  final sorted = [...items];
  sorted.sort((a, b) {
    final aNumber = _chapterNumber(a.category ?? a.title);
    final bNumber = _chapterNumber(b.category ?? b.title);
    if (aNumber != null && bNumber != null && aNumber != bNumber) {
      return aNumber.compareTo(bNumber);
    }
    if (aNumber != null && bNumber == null) return -1;
    if (aNumber == null && bNumber != null) return 1;
    return (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  });
  return sorted;
}

int? _chapterNumber(String value) {
  final match = RegExp(r'(\d+)').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(1) ?? '');
}

class _EmptyReminderCard extends StatelessWidget {
  const _EmptyReminderCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.notifications_none_outlined),
        title: Text('Không có lịch nhắc'),
        subtitle: Text('Tạo lịch nhắc để app báo giờ tụng kinh.'),
      ),
    );
  }
}

enum _ReadingFlow { horizontal, vertical }

class ScriptureReadingScreen extends ConsumerWidget {
  const ScriptureReadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingsAsync = ref.watch(scriptureReadingListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kinh đọc')),
      body: readingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('Không tải được Kinh đọc')),
        data: (readings) => RefreshIndicator(
          onRefresh: () async {
            await refreshPublicContent(ref);
            await ref.read(scriptureReadingListProvider.future);
          },
          child: readings.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.menu_book_outlined),
                        title: Text('Chưa có Kinh đọc'),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  itemCount: readings.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = readings[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.auto_stories_outlined),
                        title: Text(item.title),
                        subtitle: Text(
                          (item.description?.trim().isNotEmpty ?? false)
                              ? item.description!
                              : _plainReadingPreview(item.content ?? ''),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ScriptureBookReader(reading: item),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class ScriptureBookReader extends StatefulWidget {
  const ScriptureBookReader({required this.reading, super.key});

  final Scripture reading;

  @override
  State<ScriptureBookReader> createState() => _ScriptureBookReaderState();
}

class _ScriptureBookReaderState extends State<ScriptureBookReader> {
  double _fontSize = 18;
  String _fontFamily = 'Serif';
  _ReadingFlow _flow = _ReadingFlow.horizontal;
  bool _blueLightFilter = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      apiClient.post('/scripture-readings/${widget.reading.id}/view', {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _readingPages(widget.reading.content ?? '');
    final background = _blueLightFilter
        ? const Color(0xFF2B221A)
        : const Color(0xFFFFFBF1);
    final textColor = _blueLightFilter
        ? const Color(0xFFF5D7A1)
        : const Color(0xFF2D2118);
    final baseStyle = TextStyle(
      color: textColor,
      fontSize: _fontSize,
      height: 1.62,
      fontFamily: _fontFamily == 'Default' ? null : _fontFamily,
    );

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(widget.reading.title),
        actions: [
          IconButton(
            tooltip: 'Tùy chỉnh đọc',
            onPressed: () => _showReadingSettings(context),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_flow == _ReadingFlow.horizontal)
            PageView.builder(
              itemCount: pages.length,
              itemBuilder: (context, index) => _BookPage(
                title: index == 0 ? widget.reading.title : null,
                content: pages[index],
                pageLabel: '${index + 1}/${pages.length}',
                baseStyle: baseStyle,
                blueLightFilter: _blueLightFilter,
              ),
            )
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 96),
              children: [
                Text(
                  widget.reading.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontFamily: _fontFamily == 'Default' ? null : _fontFamily,
                  ),
                ),
                const SizedBox(height: 18),
                RichContent(
                  content: widget.reading.content ?? '',
                  baseStyle: baseStyle,
                ),
              ],
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: _ReadingQuickBar(
              fontSize: _fontSize,
              blueLightFilter: _blueLightFilter,
              flow: _flow,
              onSmaller: () =>
                  setState(() => _fontSize = (_fontSize - 1).clamp(15, 30)),
              onLarger: () =>
                  setState(() => _fontSize = (_fontSize + 1).clamp(15, 30)),
              onToggleBlueLight: () =>
                  setState(() => _blueLightFilter = !_blueLightFilter),
              onToggleFlow: () => setState(
                () => _flow = _flow == _ReadingFlow.horizontal
                    ? _ReadingFlow.vertical
                    : _ReadingFlow.horizontal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReadingSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tùy chỉnh',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text('Cỡ chữ ${_fontSize.toStringAsFixed(0)}'),
                Slider(
                  min: 15,
                  max: 30,
                  divisions: 15,
                  value: _fontSize,
                  onChanged: (value) {
                    setSheetState(() => _fontSize = value);
                    setState(() {});
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _fontFamily,
                  decoration: const InputDecoration(labelText: 'Font chữ'),
                  items: const [
                    DropdownMenuItem(value: 'Serif', child: Text('Serif')),
                    DropdownMenuItem(value: 'Sans', child: Text('Sans')),
                    DropdownMenuItem(value: 'Mono', child: Text('Mono')),
                    DropdownMenuItem(value: 'Default', child: Text('Mặc định')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setSheetState(() => _fontFamily = value);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Giảm ánh sáng xanh'),
                  value: _blueLightFilter,
                  onChanged: (value) {
                    setSheetState(() => _blueLightFilter = value);
                    setState(() {});
                  },
                ),
                SegmentedButton<_ReadingFlow>(
                  segments: const [
                    ButtonSegment(
                      value: _ReadingFlow.horizontal,
                      icon: Icon(Icons.swipe),
                      label: Text('Lật ngang'),
                    ),
                    ButtonSegment(
                      value: _ReadingFlow.vertical,
                      icon: Icon(Icons.swap_vert),
                      label: Text('Vuốt lên'),
                    ),
                  ],
                  selected: {_flow},
                  onSelectionChanged: (value) {
                    setSheetState(() => _flow = value.first);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookPage extends StatelessWidget {
  const _BookPage({
    required this.content,
    required this.pageLabel,
    required this.baseStyle,
    required this.blueLightFilter,
    this.title,
  });

  final String content;
  final String pageLabel;
  final TextStyle baseStyle;
  final bool blueLightFilter;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final textColor = baseStyle.color ?? const Color(0xFF2D2118);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 92),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: blueLightFilter
              ? const Color(0xFF35281E)
              : const Color(0xFFFFFFFA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: blueLightFilter
                ? const Color(0xFF6D5139)
                : const Color(0xFFE5D5B8),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontFamily: baseStyle.fontFamily,
                ),
              ),
              const SizedBox(height: 18),
            ],
            RichContent(content: content, baseStyle: baseStyle),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                pageLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: .62),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingQuickBar extends StatelessWidget {
  const _ReadingQuickBar({
    required this.fontSize,
    required this.blueLightFilter,
    required this.flow,
    required this.onSmaller,
    required this.onLarger,
    required this.onToggleBlueLight,
    required this.onToggleFlow,
  });

  final double fontSize;
  final bool blueLightFilter;
  final _ReadingFlow flow;
  final VoidCallback onSmaller;
  final VoidCallback onLarger;
  final VoidCallback onToggleBlueLight;
  final VoidCallback onToggleFlow;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'Giảm cỡ chữ',
              onPressed: onSmaller,
              icon: const Icon(Icons.text_decrease),
            ),
            Text(fontSize.toStringAsFixed(0)),
            IconButton(
              tooltip: 'Tăng cỡ chữ',
              onPressed: onLarger,
              icon: const Icon(Icons.text_increase),
            ),
            IconButton(
              tooltip: 'Giảm ánh sáng xanh',
              onPressed: onToggleBlueLight,
              icon: Icon(
                blueLightFilter
                    ? Icons.nightlight_round
                    : Icons.nightlight_outlined,
              ),
            ),
            IconButton(
              tooltip: flow == _ReadingFlow.horizontal
                  ? 'Đổi sang vuốt lên'
                  : 'Đổi sang lật ngang',
              onPressed: onToggleFlow,
              icon: Icon(
                flow == _ReadingFlow.horizontal ? Icons.swipe : Icons.swap_vert,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _readingPages(String content) {
  final blocks =
      RegExp(
            r'<(?:h[1-3]|p|blockquote|ul|ol|figure)[\s\S]*?</(?:h[1-3]|p|blockquote|ul|ol|figure)>',
            caseSensitive: false,
          )
          .allMatches(content)
          .map((match) => match.group(0) ?? '')
          .where((block) => block.trim().isNotEmpty)
          .toList();

  final sourceBlocks = blocks.isEmpty
      ? content
            .split(RegExp(r'\n{2,}'))
            .where((block) => block.trim().isNotEmpty)
            .toList()
      : blocks;
  if (sourceBlocks.isEmpty) return [''];

  final pages = <String>[];
  final buffer = StringBuffer();
  var chars = 0;
  for (final block in sourceBlocks) {
    final length = _plainReadingPreview(block).length;
    if (buffer.isNotEmpty && chars + length > 1500) {
      pages.add(buffer.toString());
      buffer.clear();
      chars = 0;
    }
    buffer.write(block);
    buffer.write('\n\n');
    chars += length;
  }
  if (buffer.isNotEmpty) pages.add(buffer.toString());
  return pages.isEmpty ? [content] : pages;
}

String _plainReadingPreview(String content) {
  return content
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class ScriptureReader extends ConsumerStatefulWidget {
  const ScriptureReader({
    required this.scripture,
    this.reminderId,
    this.initialLineIndex = 0,
    this.chapterSequence = const [],
    this.chapterIndex = 0,
    this.autoAdvanceChapters = false,
    this.autoStart = false,
    super.key,
  });

  final Scripture scripture;
  final String? reminderId;
  final int initialLineIndex;
  final List<Scripture> chapterSequence;
  final int chapterIndex;
  final bool autoAdvanceChapters;
  final bool autoStart;

  @override
  ConsumerState<ScriptureReader> createState() => _ScriptureReaderState();
}

class _ScriptureRitualPause {
  const _ScriptureRitualPause({
    required this.note,
    required this.summary,
    required this.duration,
  });

  final String note;
  final String summary;
  final Duration duration;
}

_ScriptureRitualPause? _detectScriptureRitualPause(String content) {
  final match = RegExp(
    r'[\(\[]([^()\[\]]{1,140})[\)\]]\s*[.!?。．]*\s*$',
    caseSensitive: false,
  ).firstMatch(content.trim());
  if (match == null) return null;

  final note = match.group(1)?.trim() ?? '';
  if (note.isEmpty) return null;

  final rawNote = note.toLowerCase();
  final normalized = _foldVietnamese(note);
  final hasMo = rawNote.contains('mõ');
  final hasRitualKeyword =
      normalized.contains('lay') ||
      normalized.contains('xa') ||
      normalized.contains('chuong') ||
      normalized.contains('khanh') ||
      hasMo;
  if (!hasRitualKeyword) return null;

  var seconds = 0;
  final parts = normalized
      .split(RegExp(r'[,;+/]|\s+va\s+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);

  for (final part in parts) {
    final count = _extractRitualCount(part);
    if (part.contains('lay')) {
      seconds += count * 5;
    } else if (part.contains('xa')) {
      seconds += count * 4;
    } else if (part.contains('chuong') ||
        part.contains('khanh') ||
        (hasMo && part.contains('mo'))) {
      seconds += count * 3;
    }
  }

  if (seconds == 0 && hasRitualKeyword) seconds = 4;
  final duration = Duration(seconds: seconds.clamp(3, 90).toInt());
  return _ScriptureRitualPause(
    note: note,
    summary: _ritualSummary(note),
    duration: duration,
  );
}

int _extractRitualCount(String text) {
  final numeric = RegExp(r'\b(\d{1,3})\b').firstMatch(text);
  if (numeric != null) return int.tryParse(numeric.group(1) ?? '') ?? 1;

  const words = {
    'mot': 1,
    'hai': 2,
    'ba': 3,
    'bon': 4,
    'tu': 4,
    'nam': 5,
    'sau': 6,
    'bay': 7,
    'tam': 8,
    'chin': 9,
    'muoi': 10,
  };
  for (final entry in words.entries) {
    if (RegExp('\\b${entry.key}\\b').hasMatch(text)) return entry.value;
  }
  return 1;
}

String _foldVietnamese(String value) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  var result = value.toLowerCase();
  for (final entry in groups.entries) {
    for (final char in entry.value.split('')) {
      result = result.replaceAll(char, entry.key);
    }
  }
  return result;
}

String _ritualSummary(String note) {
  final text = note.trim();
  if (text.isEmpty) return 'Thao tác nghi lễ';
  return text[0].toUpperCase() + text.substring(1);
}

class _ScriptureReaderState extends ConsumerState<ScriptureReader> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(0);
  final Set<String> _completedRitualPauseKeys = <String>{};
  Timer? _timer;
  Timer? _controlsHideTimer;
  Timer? _chapterAdvanceTimer;
  _ScriptureRitualPause? _ritualPause;
  Duration _ritualPauseRemaining = Duration.zero;
  Duration _ritualPauseTotal = Duration.zero;
  Duration? _ritualPauseResumeElapsed;
  int? _ritualPauseIndex;
  double _speed = 1;
  String _speedMode = 'normal';
  bool _speedTouched = false;
  bool _savingSpeedPreference = false;
  String? _loadedSpeedScope;
  String _repeatMode = 'off';
  int _customRepeatCount = 5;
  int _completedRepeats = 0;
  String _backgroundUrl = '';
  Duration _elapsed = Duration.zero;
  bool _playing = false;
  bool _autoAdvanceChapters = false;
  bool _controlsVisible = true;
  int _chapterAdvanceCountdown = 0;
  DateTime? _lastTick;
  double _fontSize = 24;

  double get _itemHeight => (_fontSize * 3.8).clamp(82, 142);
  bool get _ritualPauseActive =>
      _ritualPause != null && _ritualPauseRemaining > Duration.zero;
  bool get _hasChapterSequence =>
      widget.chapterSequence.length > 1 &&
      widget.chapterIndex >= 0 &&
      widget.chapterIndex < widget.chapterSequence.length;
  Scripture? get _nextChapter =>
      _hasChapterSequence &&
          widget.chapterIndex < widget.chapterSequence.length - 1
      ? widget.chapterSequence[widget.chapterIndex + 1]
      : null;

  @override
  void initState() {
    super.initState();
    unawaited(apiClient.post('/scriptures/${widget.scripture.id}/view', {}));
    final safeIndex = widget.initialLineIndex.clamp(
      0,
      widget.scripture.lines.length - 1,
    );
    _activeIndex.value = safeIndex;
    _elapsed = widget.scripture.lines[safeIndex].startTime;
    _backgroundUrl = widget.scripture.backgroundImageUrl ?? '';
    _autoAdvanceChapters = widget.autoAdvanceChapters;
    unawaited(_loadSavedSpeedPreference());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerLine(safeIndex, jump: true);
      _scheduleControlsHide();
      if (widget.autoStart) _startPlayback();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controlsHideTimer?.cancel();
    _chapterAdvanceTimer?.cancel();
    _activeIndex.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleControlsHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  void _toggle() {
    _showControls();
    final shouldPlay = !_playing;
    setState(() {
      _playing = shouldPlay;
      if (shouldPlay && _elapsed >= _endTime) {
        _elapsed = _startTime;
        _completedRepeats = 0;
        _clearRitualPause();
        _completedRitualPauseKeys.clear();
        _setActiveIndex(0);
      }
    });
    if (shouldPlay) {
      _startPlayback();
    } else {
      _timer?.cancel();
    }
  }

  void _startPlayback() {
    _chapterAdvanceTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _playing = true;
      _chapterAdvanceCountdown = 0;
    });
    _lastTick = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    final delta = now.difference(_lastTick ?? now);
    _lastTick = now;

    if (_ritualPauseActive) {
      final remaining = _ritualPauseRemaining - delta;
      if (remaining > Duration.zero) {
        setState(() => _ritualPauseRemaining = remaining);
        return;
      }

      final resumeElapsed = _ritualPauseResumeElapsed ?? _elapsed;
      final pauseIndex = _ritualPauseIndex;
      if (pauseIndex != null) {
        _completedRitualPauseKeys.add(_ritualPauseKey(pauseIndex));
      }
      setState(() {
        _elapsed = resumeElapsed;
        _clearRitualPause();
      });
      if (_elapsed >= _endTime) {
        _handleCompletedPass();
        return;
      }
      _setActiveIndex(_indexFor(_elapsed));
      return;
    }

    final nextElapsed =
        _elapsed +
        Duration(milliseconds: (delta.inMilliseconds * _speed).round());
    final currentIndex = _activeIndex.value;
    final nextIndex = _indexFor(nextElapsed);

    if (nextElapsed >= _endTime) {
      if (_maybeStartRitualPause(currentIndex, _endTime)) return;
      _handleCompletedPass();
      return;
    }

    if (nextIndex > currentIndex &&
        _maybeStartRitualPause(
          currentIndex,
          widget.scripture.lines[nextIndex].startTime,
        )) {
      return;
    }

    _elapsed = nextElapsed;
    _setActiveIndex(nextIndex);
  }

  Duration get _endTime {
    if (widget.scripture.lines.isEmpty) return Duration.zero;
    return widget.scripture.lines.last.startTime + const Duration(seconds: 4);
  }

  Duration get _startTime {
    if (widget.scripture.lines.isEmpty) return Duration.zero;
    return widget.scripture.lines.first.startTime;
  }

  int get _lastLineIndex {
    if (widget.scripture.lines.isEmpty) return 0;
    return widget.scripture.lines.length - 1;
  }

  int? get _targetRepeatCount => switch (_repeatMode) {
    'three' => 3,
    'custom' => _customRepeatCount.clamp(1, 999),
    'forever' => null,
    _ => 1,
  };

  String get _repeatLabel => switch (_repeatMode) {
    'three' => 'Lặp 3 lần',
    'custom' => 'Lặp $_customRepeatCount lần',
    'forever' => 'Lặp liên tục',
    _ => 'Không lặp',
  };

  bool get _repeatEnabled => _repeatMode != 'off';

  void _handleCompletedPass() {
    final target = _targetRepeatCount;
    final nextCompleted = _completedRepeats + 1;
    if (target == null || nextCompleted < target) {
      setState(() {
        _completedRepeats = nextCompleted;
        _elapsed = _startTime;
      });
      _setActiveIndex(0);
      return;
    }
    setState(() {
      _completedRepeats = nextCompleted;
      _playing = false;
      _elapsed = _endTime;
    });
    _timer?.cancel();
    _setActiveIndex(_lastLineIndex);
    if (_autoAdvanceChapters && _nextChapter != null) {
      _scheduleNextChapter();
    }
  }

  void _scheduleNextChapter() {
    _chapterAdvanceTimer?.cancel();
    setState(() => _chapterAdvanceCountdown = 3);
    _chapterAdvanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_chapterAdvanceCountdown <= 1) {
        timer.cancel();
        _openNextChapter(autoStart: true);
        return;
      }
      setState(() => _chapterAdvanceCountdown -= 1);
    });
  }

  void _openNextChapter({bool autoStart = false}) {
    final next = _nextChapter;
    if (next == null) return;
    _timer?.cancel();
    _chapterAdvanceTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ScriptureReader(
          scripture: next,
          chapterSequence: widget.chapterSequence,
          chapterIndex: widget.chapterIndex + 1,
          autoAdvanceChapters: _autoAdvanceChapters,
          autoStart: autoStart,
        ),
      ),
    );
  }

  int _indexFor(Duration elapsed) {
    var index = 0;
    for (var i = 0; i < widget.scripture.lines.length; i++) {
      if (elapsed >= widget.scripture.lines[i].startTime) index = i;
    }
    return index;
  }

  void _setActiveIndex(int index) {
    if (_activeIndex.value == index) return;
    _activeIndex.value = index;
    if (widget.reminderId != null) {
      ref
          .read(scriptureReminderProvider.notifier)
          .saveProgress(widget.reminderId!, index)
          .ignore();
    }
    _centerLine(index);
  }

  bool _maybeStartRitualPause(int index, Duration resumeElapsed) {
    if (index < 0 || index >= widget.scripture.lines.length) return false;
    if (_completedRitualPauseKeys.contains(_ritualPauseKey(index))) {
      return false;
    }

    final pause = _detectScriptureRitualPause(
      widget.scripture.lines[index].content,
    );
    if (pause == null) return false;

    setState(() {
      _ritualPause = pause;
      _ritualPauseIndex = index;
      _ritualPauseTotal = pause.duration;
      _ritualPauseRemaining = pause.duration;
      _ritualPauseResumeElapsed = resumeElapsed;
    });
    _centerLine(index);
    return true;
  }

  String _ritualPauseKey(int index) => '$_completedRepeats:$index';

  void _clearRitualPause() {
    _ritualPause = null;
    _ritualPauseIndex = null;
    _ritualPauseRemaining = Duration.zero;
    _ritualPauseTotal = Duration.zero;
    _ritualPauseResumeElapsed = null;
  }

  void _centerLine(int index, {bool jump = false}) {
    if (!_scrollController.hasClients) return;
    final offset = (index * _itemHeight) + (_itemHeight / 2);
    final target = offset
        .clamp(0, _scrollController.position.maxScrollExtent)
        .toDouble();
    if (jump) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _jumpToLine(int index) {
    _showControls();
    _chapterAdvanceTimer?.cancel();
    setState(() {
      _elapsed = widget.scripture.lines[index].startTime;
      _completedRepeats = 0;
      _chapterAdvanceCountdown = 0;
      _clearRitualPause();
      _completedRitualPauseKeys.clear();
    });
    _setActiveIndex(index);
  }

  void _restart() {
    _showControls();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tụng lại từ đầu?'),
        content: const Text(
          'Tiến trình đang dừng sẽ được đưa về dòng đầu tiên của bài kinh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _elapsed = _startTime;
                _playing = false;
                _completedRepeats = 0;
                _chapterAdvanceCountdown = 0;
                _clearRitualPause();
                _completedRitualPauseKeys.clear();
                _timer?.cancel();
                _chapterAdvanceTimer?.cancel();
              });
              _setActiveIndex(0);
            },
            child: const Text('Tụng lại'),
          ),
        ],
      ),
    );
  }

  void _selectSpeed(String value) {
    _showControls();
    setState(() {
      _speedTouched = true;
      _loadedSpeedScope = null;
      _speedMode = value;
      if (value == 'slow') _speed = .75;
      if (value == 'normal') _speed = 1;
      if (value == 'fast') _speed = 1.25;
    });
  }

  Future<void> _loadSavedSpeedPreference() async {
    if (apiClient.accessToken == null) return;
    try {
      final payload = await apiClient.getMap(
        '/me/scripture-reading-preferences?scriptureId=${Uri.encodeComponent(widget.scripture.id)}',
      );
      final effective = payload['effective'];
      if (effective is! Map<String, dynamic>) return;
      final speed = _readPreferenceSpeed(effective['speed']);
      if (speed == null) return;
      final speedMode = _normalizeSpeedMode(effective['speedMode'], speed);
      final scope = effective['scope'] as String?;
      if (!mounted || _speedTouched) return;
      setState(() {
        _speed = speed.clamp(.25, 3).toDouble();
        _speedMode = speedMode;
        _loadedSpeedScope = scope;
      });
    } catch (_) {
      // Không chặn màn đọc nếu phiên đăng nhập hết hạn hoặc mạng chập chờn.
    }
  }

  double? _readPreferenceSpeed(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _normalizeSpeedMode(Object? value, double speed) {
    final mode = value is String ? value : '';
    if (mode == 'slow' ||
        mode == 'normal' ||
        mode == 'fast' ||
        mode == 'custom') {
      return mode;
    }
    if (speed <= .8) return 'slow';
    if (speed >= 1.2) return 'fast';
    return 'normal';
  }

  void _showSaveSpeedSheet() {
    _showControls();
    if (apiClient.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đăng nhập để lưu tốc độ đọc theo tài khoản.'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Đăng nhập',
            onPressed: () => context.push('/login'),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lưu tốc độ đọc',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tốc độ hiện tại: ${_speed.toStringAsFixed(2)}x - $_speedLabel',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Lưu cho riêng bộ kinh này'),
                  subtitle: Text(widget.scripture.title),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_saveSpeedPreference('SCRIPTURE'));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('Lưu cho toàn bộ tài khoản'),
                  subtitle: const Text(
                    'Các bài kinh sau sẽ tự dùng tốc độ này.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_saveSpeedPreference('GLOBAL'));
                  },
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveSpeedPreference(String scope) async {
    if (_savingSpeedPreference) return;
    setState(() => _savingSpeedPreference = true);
    try {
      await apiClient.post('/me/scripture-reading-preferences', {
        'scope': scope,
        if (scope == 'SCRIPTURE') 'scriptureId': widget.scripture.id,
        'speed': _speed.clamp(.25, 3),
        'speedMode': _speedMode,
      });
      if (!mounted) return;
      setState(() => _loadedSpeedScope = scope);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scope == 'SCRIPTURE'
                ? 'Đã lưu tốc độ cho riêng bộ kinh này.'
                : 'Đã lưu tốc độ cho toàn bộ tài khoản.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được tốc độ đọc: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingSpeedPreference = false);
    }
  }

  void _selectRepeat(String value) {
    _showControls();
    setState(() {
      _repeatMode = value;
      _completedRepeats = 0;
      _chapterAdvanceCountdown = 0;
      _completedRitualPauseKeys.clear();
      _clearRitualPause();
    });
  }

  String get _speedLabel => switch (_speedMode) {
    'slow' => 'Chậm',
    'fast' => 'Nhanh',
    'custom' => 'Tùy chỉnh',
    _ => 'Bình thường',
  };

  void _showBackgroundSheet() {
    final options = [
      ['', 'Không - nền đen'],
      if (widget.scripture.backgroundImageUrl != null &&
          widget.scripture.backgroundImageUrl!.isNotEmpty)
        [widget.scripture.backgroundImageUrl!, 'Ảnh nền từ admin'],
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                ListTile(
                  leading: Icon(
                    option[0].isEmpty
                        ? Icons.dark_mode_outlined
                        : Icons.image_outlined,
                  ),
                  title: Text(option[1]),
                  trailing: _backgroundUrl == option[0]
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    setState(() => _backgroundUrl = option[0]);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.scripture.lines;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0D0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFFFF8E8),
        title: Text(widget.scripture.title),
        actions: [
          IconButton(
            tooltip: 'Chọn ảnh nền',
            onPressed: _showBackgroundSheet,
            icon: const Icon(Icons.wallpaper_outlined),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _showControls,
        child: Stack(
          children: [
            if (_backgroundUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  _backgroundUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _backgroundUrl.isEmpty
                      ? const Color(0xFF0F0D0A)
                      : Colors.black.withValues(alpha: .58),
                ),
              ),
            ),
            Positioned.fill(
              child: ValueListenableBuilder<int>(
                valueListenable: _activeIndex,
                builder: (context, activeIndex, _) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          24,
                          constraints.maxHeight / 2,
                          24,
                          constraints.maxHeight / 2,
                        ),
                        itemExtent: _itemHeight,
                        itemCount: lines.length,
                        itemBuilder: (context, index) {
                          final active = index == activeIndex;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _jumpToLine(index),
                            child: AnimatedScale(
                              scale: active ? 1.08 : 1,
                              duration: const Duration(milliseconds: 180),
                              child: AnimatedOpacity(
                                opacity: active ? 1 : .34,
                                duration: const Duration(milliseconds: 180),
                                child: Center(
                                  child: Text(
                                    lines[index].content,
                                    textAlign: TextAlign.center,
                                    maxLines: 4,
                                    overflow: TextOverflow.fade,
                                    softWrap: true,
                                    style: TextStyle(
                                      color: active
                                          ? const Color(0xFFFFE8A3)
                                          : const Color(0xFFFFF8E8),
                                      fontSize: active
                                          ? _fontSize + 2
                                          : _fontSize,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      height: 1.32,
                                      shadows: active
                                          ? const [
                                              Shadow(
                                                color: Color(0xFFFFE8A3),
                                                blurRadius: 18,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedSlide(
                    offset: _controlsVisible
                        ? Offset.zero
                        : const Offset(0, 1.08),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _toggle,
                                    icon: Icon(
                                      _playing ? Icons.pause : Icons.play_arrow,
                                    ),
                                    label: Text(_playing ? 'Tạm dừng' : 'Tụng'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton.filledTonal(
                                  tooltip: 'Tụng lại từ đầu',
                                  onPressed: _restart,
                                  icon: const Icon(Icons.restart_alt),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                PopupMenuButton<String>(
                                  tooltip: 'Chế độ lặp lại',
                                  onSelected: _selectRepeat,
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'off',
                                      child: _OptionMenuLabel(
                                        icon: Icons.block,
                                        label: 'Không lặp',
                                        selected: _repeatMode == 'off',
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'three',
                                      child: _OptionMenuLabel(
                                        icon: Icons.repeat,
                                        label: 'Lặp 3 lần',
                                        selected: _repeatMode == 'three',
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'forever',
                                      child: _OptionMenuLabel(
                                        icon: Icons.all_inclusive,
                                        label: 'Lặp liên tục',
                                        selected: _repeatMode == 'forever',
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'custom',
                                      child: _OptionMenuLabel(
                                        icon: Icons.tune,
                                        label: 'Tùy chỉnh',
                                        selected: _repeatMode == 'custom',
                                      ),
                                    ),
                                  ],
                                  child: _ReaderControlChip(
                                    icon: Icons.repeat,
                                    label: _repeatEnabled
                                        ? _repeatLabel
                                        : 'Bật lặp',
                                    selected: _repeatEnabled,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Tốc độ đọc',
                                  onSelected: _selectSpeed,
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'slow',
                                      child: _SpeedMenuLabel(
                                        label: 'Chậm',
                                        speed: '',
                                        selected: _speedMode == 'slow',
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'normal',
                                      child: _SpeedMenuLabel(
                                        label: 'Bình thường',
                                        speed: '',
                                        selected: _speedMode == 'normal',
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'fast',
                                      child: _SpeedMenuLabel(
                                        label: 'Nhanh',
                                        speed: '',
                                        selected: _speedMode == 'fast',
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'custom',
                                      child: _SpeedMenuLabel(
                                        label: 'Tùy chỉnh',
                                        speed: '${_speed.toStringAsFixed(2)}x',
                                        selected: _speedMode == 'custom',
                                      ),
                                    ),
                                  ],
                                  child: _ReaderControlChip(
                                    icon: Icons.speed,
                                    label: _speedLabel,
                                  ),
                                ),
                                PopupMenuButton<double>(
                                  tooltip: 'Cỡ chữ',
                                  onSelected: (value) {
                                    _showControls();
                                    setState(() => _fontSize = value);
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                          (_) =>
                                              _centerLine(_activeIndex.value),
                                        );
                                  },
                                  itemBuilder: (context) => [
                                    for (final option in const [
                                      20.0,
                                      24.0,
                                      28.0,
                                      32.0,
                                    ])
                                      PopupMenuItem(
                                        value: option,
                                        child: _SpeedMenuLabel(
                                          label: option == 20
                                              ? 'Nhỏ'
                                              : option == 24
                                              ? 'Vừa'
                                              : option == 28
                                              ? 'Lớn'
                                              : 'Rất lớn',
                                          speed: option.toStringAsFixed(0),
                                          selected: _fontSize == option,
                                        ),
                                      ),
                                  ],
                                  child: _ReaderControlChip(
                                    icon: Icons.format_size,
                                    label: 'Cỡ ${_fontSize.toStringAsFixed(0)}',
                                  ),
                                ),
                                if (_hasChapterSequence)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: _nextChapter == null
                                        ? null
                                        : () => _openNextChapter(),
                                    child: _ReaderControlChip(
                                      icon: Icons.skip_next_outlined,
                                      label: _nextChapter == null
                                          ? 'Hết phẩm'
                                          : 'Phẩm tiếp',
                                      selected: false,
                                      showArrow: false,
                                    ),
                                  ),
                                if (_hasChapterSequence)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () {
                                      _showControls();
                                      setState(
                                        () => _autoAdvanceChapters =
                                            !_autoAdvanceChapters,
                                      );
                                    },
                                    child: _ReaderControlChip(
                                      icon: Icons.playlist_play_outlined,
                                      label: 'Tự qua phẩm',
                                      selected: _autoAdvanceChapters,
                                      showArrow: false,
                                    ),
                                  ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: _savingSpeedPreference
                                      ? null
                                      : _showSaveSpeedSheet,
                                  child: _ReaderControlChip(
                                    icon: _savingSpeedPreference
                                        ? Icons.sync
                                        : Icons.bookmark_added_outlined,
                                    label: _loadedSpeedScope == 'SCRIPTURE'
                                        ? 'Đã lưu bài này'
                                        : _loadedSpeedScope == 'GLOBAL'
                                        ? 'Đã lưu chung'
                                        : 'Lưu thói quen',
                                    selected: _loadedSpeedScope != null,
                                    showArrow: false,
                                  ),
                                ),
                              ],
                            ),
                            if (_speedMode == 'custom')
                              Row(
                                children: [
                                  Text(
                                    '${_speed.toStringAsFixed(2)}x',
                                    style: const TextStyle(
                                      color: Color(0xFFFFF8E8),
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      min: .25,
                                      max: 3,
                                      value: _speed,
                                      onChanged: (value) {
                                        _showControls();
                                        setState(() {
                                          _speedTouched = true;
                                          _loadedSpeedScope = null;
                                          _speed = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            if (_repeatMode == 'custom')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: Color(0xFFFFF8E8),
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Số lần lặp lại',
                                    labelStyle: TextStyle(
                                      color: Color(0xFFFFF8E8),
                                    ),
                                    filled: true,
                                  ),
                                  onChanged: (value) {
                                    final parsed = int.tryParse(value);
                                    if (parsed != null && parsed > 0) {
                                      setState(
                                        () => _customRepeatCount = parsed,
                                      );
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              top: MediaQuery.paddingOf(context).top + kToolbarHeight + 10,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _ritualPauseActive && _ritualPause != null
                      ? _RitualPauseBanner(
                          key: ValueKey(_ritualPauseIndex),
                          pause: _ritualPause!,
                          remaining: _ritualPauseRemaining,
                          total: _ritualPauseTotal,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            if (_chapterAdvanceCountdown > 0 && _nextChapter != null)
              Positioned(
                left: 18,
                right: 18,
                top: MediaQuery.paddingOf(context).top + kToolbarHeight + 86,
                child: _ChapterAdvanceBanner(
                  seconds: _chapterAdvanceCountdown,
                  title: _nextChapter!.category ?? _nextChapter!.title,
                ),
              ),
            if (!_controlsVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 46,
                child: Center(
                  child: SafeArea(
                    top: false,
                    child: IconButton.filledTonal(
                      tooltip: 'Mở công cụ',
                      onPressed: _showControls,
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpeedMenuLabel extends StatelessWidget {
  const _SpeedMenuLabel({
    required this.label,
    required this.speed,
    this.selected = false,
  });

  final String label;
  final String speed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Row(
        children: [
          Icon(selected ? Icons.check_circle : Icons.circle_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          if (speed.isNotEmpty)
            Text(speed, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RitualPauseBanner extends StatelessWidget {
  const _RitualPauseBanner({
    required this.pause,
    required this.remaining,
    required this.total,
    super.key,
  });

  final _ScriptureRitualPause pause;
  final Duration remaining;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = (remaining.inMilliseconds / 1000).ceil().clamp(
      1,
      999,
    );
    final progress = total.inMilliseconds <= 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Semantics(
      liveRegion: true,
      label: 'Đang tạm nghỉ cho ${pause.summary}, còn $remainingSeconds giây.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF211A12).withValues(alpha: .92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFFFE8A3).withValues(alpha: .26),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 48,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: const Color(
                        0xFFFFF8E8,
                      ).withValues(alpha: .14),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFD36A),
                      ),
                    ),
                    Center(
                      child: Text(
                        '$remainingSeconds',
                        style: const TextStyle(
                          color: Color(0xFFFFF8E8),
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Tạm nghỉ nghi lễ',
                      style: TextStyle(
                        color: Color(0xFFFFE8A3),
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pause.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFF8E8),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.hourglass_bottom_rounded,
                color: Color(0xFFFFD36A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterAdvanceBanner extends StatelessWidget {
  const _ChapterAdvanceBanner({required this.seconds, required this.title});

  final int seconds;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF211A12).withValues(alpha: .92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFE8A3).withValues(alpha: .24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFFFD36A),
              foregroundColor: const Color(0xFF211A12),
              child: Text(
                '$seconds',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sắp chuyển sang $title',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFF8E8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionMenuLabel extends StatelessWidget {
  const _OptionMenuLabel({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Row(
        children: [
          Icon(selected ? Icons.check_circle : icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _ReaderControlChip extends StatelessWidget {
  const _ReaderControlChip({
    required this.icon,
    required this.label,
    this.selected = false,
    this.showArrow = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? Theme.of(context).colorScheme.onSecondaryContainer
        : const Color(0xFFFFF8E8);
    final background = selected
        ? Theme.of(context).colorScheme.secondaryContainer
        : const Color(0xFF2A241D);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.secondary.withValues(alpha: .55)
              : const Color(0xFFFFF8E8).withValues(alpha: .16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
          if (showArrow) ...[
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 18, color: foreground),
          ],
        ],
      ),
    );
  }
}

String _formatTime(Duration value) {
  final hour = value.inHours.remainder(24).toString().padLeft(2, '0');
  final minute = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatWeekdays(Set<int> values) {
  const labels = {
    1: 'T2',
    2: 'T3',
    3: 'T4',
    4: 'T5',
    5: 'T6',
    6: 'T7',
    7: 'CN',
  };
  return values.map((value) => labels[value] ?? value.toString()).join(', ');
}
