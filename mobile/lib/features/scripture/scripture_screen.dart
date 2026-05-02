import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_models.dart';
import '../content/content_providers.dart';

class ScriptureScreen extends ConsumerWidget {
  const ScriptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scriptures = ref.watch(scriptureListProvider);
    final reminders = ref.watch(scriptureReminderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Đọc kinh')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FilledButton.icon(
            onPressed: scriptures.isEmpty
                ? null
                : () => _showReminderSheet(context, ref, scriptures),
            icon: const Icon(Icons.add_alarm),
            label: const Text('Đặt lịch nhắc tụng kinh'),
          ),
          const SizedBox(height: 16),
          Text('Lịch nhắc', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
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
                  onChanged: (value) => ref
                      .read(scriptureReminderProvider.notifier)
                      .toggle(reminder.id, value),
                ),
                onTap: () {
                  final startIndex = reminder.resumeMode == ReminderResumeMode.resume
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
          const SizedBox(height: 20),
          Text('Bộ kinh', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          for (final scripture in scriptures)
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(scripture.title),
                subtitle: Text(scripture.description ?? '${scripture.lines.length} dòng'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScriptureReader(scripture: scripture),
                  ),
                ),
              ),
            ),
        ],
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
                  Text('Lịch nhắc tụng kinh', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  TextField(
                    controller: TextEditingController(text: title),
                    decoration: const InputDecoration(labelText: 'Tên lời nhắc'),
                    onChanged: (value) => title = value,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Scripture>(
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Bộ kinh'),
                    items: [
                      for (final scripture in scriptures)
                        DropdownMenuItem(value: scripture, child: Text(scripture.title)),
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
                    title: Text(_formatTime(Duration(hours: time.hour, minutes: time.minute))),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: time);
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
                    onSelectionChanged: (value) => setSheetState(() => resumeMode = value.first),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Lưu lịch nhắc'),
                      onPressed: weekdays.isEmpty
                          ? null
                          : () {
                              ref.read(scriptureReminderProvider.notifier).add(
                                    title: title.trim().isEmpty ? 'Nhắc tụng kinh' : title.trim(),
                                    scripture: selected,
                                    timeOfDay: Duration(hours: time.hour, minutes: time.minute),
                                    weekdays: weekdays,
                                    resumeMode: resumeMode,
                                  );
                              Navigator.pop(context);
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

class _ScriptureReaderState extends State<ScriptureReader> {
  static const double _itemHeight = 72;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(0);
  Timer? _timer;
  double _speed = 1;
  String _speedMode = 'normal';
  String _backgroundUrl = '';
  Duration _elapsed = Duration.zero;
  bool _playing = false;
  DateTime? _lastTick;

  @override
  void initState() {
    super.initState();
    final safeIndex = widget.initialLineIndex.clamp(0, widget.scripture.lines.length - 1);
    _activeIndex.value = safeIndex;
    _elapsed = widget.scripture.lines[safeIndex].startTime;
    _backgroundUrl = widget.scripture.backgroundImageUrl ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerLine(safeIndex));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _activeIndex.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _playing = !_playing);
    if (_playing) {
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
    _elapsed += Duration(milliseconds: (delta.inMilliseconds * _speed).round());
    _setActiveIndex(_indexFor(_elapsed));
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
          .saveProgress(widget.reminderId!, index);
    }
    _centerLine(index);
  }

  void _centerLine(int index) {
    if (!_scrollController.hasClients) return;
    final viewportHeight = _scrollController.position.viewportDimension;
    final offset = (index * _itemHeight) - (viewportHeight / 2) + (_itemHeight / 2);
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.linear,
    );
  }

  void _jumpToLine(int index) {
    _elapsed = widget.scripture.lines[index].startTime;
    _setActiveIndex(index);
  }

  void _restart() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đọc lại từ đầu?'),
        content: const Text('Tiến trình đang dừng sẽ được đưa về dòng đầu tiên của bài kinh.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _elapsed = Duration.zero;
                _playing = false;
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
    setState(() {
      _speedMode = value;
      if (value == 'slow') _speed = .75;
      if (value == 'normal') _speed = 1;
      if (value == 'fast') _speed = 1.25;
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
      if (widget.scripture.backgroundImageUrl != null && widget.scripture.backgroundImageUrl!.isNotEmpty)
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
                  leading: Icon(option[0].isEmpty ? Icons.dark_mode_outlined : Icons.image_outlined),
                  title: Text(option[1]),
                  trailing: _backgroundUrl == option[0] ? const Icon(Icons.check) : null,
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
      body: Stack(
        children: [
          if (_backgroundUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(_backgroundUrl, fit: BoxFit.cover),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _backgroundUrl.isEmpty ? const Color(0xFF0F0D0A) : Colors.black.withValues(alpha: .58),
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: active
                                          ? const Color(0xFFFFE8A3)
                                          : const Color(0xFFFFF8E8),
                                      fontSize: active ? 25 : 22,
                                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                      height: 1.32,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _toggle,
                            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                            label: Text(_playing ? 'Tạm dừng' : 'Đọc'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _restart,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Đọc lại'),
                          ),
                          const SizedBox(width: 10),
                          PopupMenuButton<String>(
                            onSelected: _selectSpeed,
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'slow', child: _SpeedMenuLabel(label: 'Chậm', speed: '0.75x')),
                              const PopupMenuItem(value: 'normal', child: _SpeedMenuLabel(label: 'Bình thường', speed: '1.00x')),
                              const PopupMenuItem(value: 'fast', child: _SpeedMenuLabel(label: 'Nhanh', speed: '1.25x')),
                              PopupMenuItem(value: 'custom', child: _SpeedMenuLabel(label: 'Tùy chỉnh', speed: '${_speed.toStringAsFixed(2)}x')),
                            ],
                            child: Chip(
                              avatar: const Icon(Icons.speed, size: 18),
                              label: Text('$_speedLabel ${_speed.toStringAsFixed(2)}x'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_speedMode == 'custom')
                      Row(
                        children: [
                          Text('${_speed.toStringAsFixed(2)}x', style: const TextStyle(color: Color(0xFFFFF8E8))),
                          Expanded(
                            child: Slider(
                              min: .25,
                              max: 3,
                              value: _speed,
                              onChanged: (value) => setState(() => _speed = value),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedMenuLabel extends StatelessWidget {
  const _SpeedMenuLabel({required this.label, required this.speed});

  final String label;
  final String speed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(speed, style: Theme.of(context).textTheme.bodySmall),
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
  const labels = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 7: 'CN'};
  return values.map((value) => labels[value] ?? value.toString()).join(', ');
}
