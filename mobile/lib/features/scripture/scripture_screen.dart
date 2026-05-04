import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
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
      appBar: AppBar(title: const Text('Đọc kinh')),
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
        .map((item) => item.category ?? item.title)
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
              title: Text('Chưa có bản Đọc Kinh'),
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
      final matchesQuery =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          category.toLowerCase().contains(query) ||
          (item.description ?? '').toLowerCase().contains(query);
      final matchesCategory =
          _categoryFilter == null ||
          category == _categoryFilter ||
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
                  hintText: 'Tìm kiếm bản đọc',
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
    final title = (scripture.category?.trim().isNotEmpty ?? false)
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
        group.items.length > 1 ||
        ((group.items.first.category?.trim().isNotEmpty ?? false) &&
            group.items.first.title.trim() != group.title);
    if (!shouldOpenSubcategory) {
      return _ScriptureListCard(scripture: group.items.first);
    }

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
              items: group.items,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScriptureListCard extends StatelessWidget {
  const _ScriptureListCard({required this.scripture});

  final Scripture scripture;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(scripture.title),
        subtitle: Text(
          scripture.lines.isEmpty
              ? 'Chưa có dòng kinh'
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
                  builder: (_) => ScriptureReader(scripture: scripture),
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
          for (final scripture in items) ...[
            _ScriptureListCard(scripture: scripture),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
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

class ScriptureReader extends StatefulWidget {
  const ScriptureReader({
    required this.scripture,
    this.reminderId,
    this.initialLineIndex = 0,
    super.key,
  });

  final Scripture scripture;
  final String? reminderId;
  final int initialLineIndex;

  @override
  State<ScriptureReader> createState() => _ScriptureReaderState();
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

class _ScriptureReaderState extends State<ScriptureReader> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(0);
  final Set<String> _completedRitualPauseKeys = <String>{};
  Timer? _timer;
  Timer? _controlsHideTimer;
  _ScriptureRitualPause? _ritualPause;
  Duration _ritualPauseRemaining = Duration.zero;
  Duration _ritualPauseTotal = Duration.zero;
  Duration? _ritualPauseResumeElapsed;
  int? _ritualPauseIndex;
  double _speed = 1;
  String _speedMode = 'normal';
  String _repeatMode = 'off';
  int _customRepeatCount = 5;
  int _completedRepeats = 0;
  String _backgroundUrl = '';
  Duration _elapsed = Duration.zero;
  bool _playing = false;
  bool _controlsVisible = true;
  DateTime? _lastTick;
  double _fontSize = 24;

  double get _itemHeight => (_fontSize * 3.8).clamp(82, 142);
  bool get _ritualPauseActive =>
      _ritualPause != null && _ritualPauseRemaining > Duration.zero;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerLine(safeIndex, jump: true);
      _scheduleControlsHide();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controlsHideTimer?.cancel();
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
      _lastTick = DateTime.now();
      _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    } else {
      _timer?.cancel();
    }
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
      ProviderScope.containerOf(context)
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
    setState(() {
      _elapsed = widget.scripture.lines[index].startTime;
      _completedRepeats = 0;
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
        title: const Text('Đọc lại từ đầu?'),
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
                _clearRitualPause();
                _completedRitualPauseKeys.clear();
                _timer?.cancel();
              });
              _setActiveIndex(0);
            },
            child: const Text('Đọc lại'),
          ),
        ],
      ),
    );
  }

  void _selectSpeed(String value) {
    _showControls();
    setState(() {
      _speedMode = value;
      if (value == 'slow') _speed = .75;
      if (value == 'normal') _speed = 1;
      if (value == 'fast') _speed = 1.25;
    });
  }

  void _selectRepeat(String value) {
    _showControls();
    setState(() {
      _repeatMode = value;
      _completedRepeats = 0;
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
                                    label: Text(_playing ? 'Tạm dừng' : 'Đọc'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton.filledTonal(
                                  tooltip: 'Đọc lại từ đầu',
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
                                        setState(() => _speed = value);
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
  });

  final IconData icon;
  final String label;
  final bool selected;

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
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 18, color: foreground),
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
