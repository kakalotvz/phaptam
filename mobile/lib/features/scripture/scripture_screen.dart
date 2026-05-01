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
    final scripture = scriptures.first;

    return ScriptureReader(scripture: scripture);
  }
}

class ScriptureReader extends StatefulWidget {
  const ScriptureReader({required this.scripture, super.key});

  final Scripture scripture;

  @override
  State<ScriptureReader> createState() => _ScriptureReaderState();
}

class _ScriptureReaderState extends State<ScriptureReader> {
  static const double _itemHeight = 72;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(0);
  Timer? _timer;
  double _speed = 1;
  Duration _elapsed = Duration.zero;
  bool _playing = false;
  DateTime? _lastTick;

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
    _centerLine(index);
  }

  void _centerLine(int index) {
    if (!_scrollController.hasClients) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final offset = (index * _itemHeight) - (screenHeight / 2) + (_itemHeight / 2) + 120;
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

  @override
  Widget build(BuildContext context) {
    final lines = widget.scripture.lines;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0D0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFFFF8E8),
        title: Text(widget.scripture.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _activeIndex,
              builder: (context, activeIndex, _) {
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: MediaQuery.sizeOf(context).height * .36,
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
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _toggle,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                        label: Text(_playing ? 'Tạm dừng' : 'Đọc'),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(label: const Text('Chậm'), selected: _speed == .75, onSelected: (_) => setState(() => _speed = .75)),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('Bình thường'), selected: _speed == 1, onSelected: (_) => setState(() => _speed = 1)),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('Nhanh'), selected: _speed == 1.25, onSelected: (_) => setState(() => _speed = 1.25)),
                    ],
                  ),
                  Row(
                    children: [
                      Text('${_speed.toStringAsFixed(2)}x', style: const TextStyle(color: Color(0xFFFFF8E8))),
                      Expanded(
                        child: Slider(
                          min: .5,
                          max: 2,
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
        ],
      ),
    );
  }
}
