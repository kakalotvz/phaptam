import 'dart:async';

import 'package:flutter/material.dart';

class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  static const durations = [5, 10, 15, 30];
  int selectedMinutes = 10;
  int remainingSeconds = 600;
  bool customDuration = false;
  int customValue = 20;
  String customUnit = 'minutes';
  Timer? timer;

  bool get isRunning => timer != null;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void toggle() {
    if (isRunning) {
      timer?.cancel();
      setState(() => timer = null);
      return;
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds <= 1) {
        timer?.cancel();
        setState(() {
          timer = null;
          remainingSeconds = selectedMinutes * 60;
        });
      } else {
        setState(() => remainingSeconds--);
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Thiền',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                width: isRunning ? 210 : 180,
                height: isRunning ? 210 : 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: .45),
                    width: 2,
                  ),
                  color: const Color(0xFF1F1B18),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              const SizedBox(height: 38),
              Wrap(
                spacing: 10,
                children: [
                  for (final value in durations)
                    ChoiceChip(
                      label: Text('$value phút'),
                      selected: !customDuration && selectedMinutes == value,
                      onSelected: isRunning
                          ? null
                          : (_) => setState(() {
                              customDuration = false;
                              selectedMinutes = value;
                              remainingSeconds = value * 60;
                            }),
                    ),
                  ChoiceChip(
                    label: const Text('Tùy chỉnh'),
                    selected: customDuration,
                    onSelected: isRunning
                        ? null
                        : (_) => setState(() {
                              customDuration = true;
                              _applyCustomDuration();
                            }),
                  ),
                ],
              ),
              if (customDuration) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Thời lượng',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed == null || parsed <= 0) return;
                          setState(() {
                            customValue = parsed;
                            _applyCustomDuration();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'minutes', label: Text('Phút')),
                        ButtonSegment(value: 'hours', label: Text('Giờ')),
                      ],
                      selected: {customUnit},
                      onSelectionChanged: isRunning
                          ? null
                          : (value) => setState(() {
                                customUnit = value.first;
                                _applyCustomDuration();
                              }),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: toggle,
                icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                label: Text(isRunning ? 'Tạm dừng' : 'Bắt đầu'),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.water_drop_outlined),
                label: const Text('Âm thanh nền'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _applyCustomDuration() {
    final minutes = customUnit == 'hours' ? customValue * 60 : customValue;
    selectedMinutes = minutes;
    remainingSeconds = minutes * 60;
  }
}
