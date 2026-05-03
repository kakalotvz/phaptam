import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/offline/media_downloads.dart';
import '../../shared/widgets/media_download_button.dart';
import '../content/content_models.dart';
import '../content/content_providers.dart';

class MeditationScreen extends ConsumerStatefulWidget {
  const MeditationScreen({super.key});

  @override
  ConsumerState<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends ConsumerState<MeditationScreen> {
  static const durations = [5, 10, 15, 30];
  int selectedMinutes = 10;
  int remainingSeconds = 600;
  bool customDuration = false;
  int customValue = 20;
  String customUnit = 'minutes';
  Timer? timer;
  AudioPlayer? backgroundPlayer;
  MeditationProgram? selectedProgram;

  bool get isRunning => timer != null;

  @override
  void dispose() {
    timer?.cancel();
    backgroundPlayer?.dispose();
    super.dispose();
  }

  Future<void> toggle() async {
    if (isRunning) {
      timer?.cancel();
      await backgroundPlayer?.pause();
      setState(() => timer = null);
      return;
    }
    final detectedDuration = await _startBackgroundAudio();
    if (detectedDuration != null && detectedDuration.inSeconds > 0) {
      final detectedSeconds = detectedDuration.inSeconds;
      setState(() {
        selectedMinutes = (detectedSeconds / 60).ceil();
        remainingSeconds = detectedSeconds;
      });
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds <= 1) {
        timer?.cancel();
        unawaited(backgroundPlayer?.stop());
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
    final programs = ref.watch(meditationProgramsProvider);
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(meditationProgramsProvider);
            await ref.read(meditationProgramsProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
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
                            color: const Color(
                              0xFFD4AF37,
                            ).withValues(alpha: .45),
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
                              selected:
                                  !customDuration && selectedMinutes == value,
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
                                ButtonSegment(
                                  value: 'minutes',
                                  label: Text('Phút'),
                                ),
                                ButtonSegment(
                                  value: 'hours',
                                  label: Text('Giờ'),
                                ),
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
                        onPressed: () => unawaited(toggle()),
                        icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                        label: Text(isRunning ? 'Tạm dừng' : 'Bắt đầu'),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.water_drop_outlined),
                        label: const Text('Âm thanh nền'),
                      ),
                      const SizedBox(height: 18),
                      programs.when(
                        data: (items) => items.isEmpty
                            ? const _EmptyMeditationProgram()
                            : _ProgramChooser(
                                programs: items,
                                selectedProgramId: selectedProgram?.id,
                                enabled: !isRunning,
                                onSelected: _selectProgram,
                              ),
                        loading: () => const _EmptyMeditationProgram(),
                        error: (error, stackTrace) =>
                            const _EmptyMeditationProgram(),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
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

  void _selectProgram(MeditationProgram program) {
    final seconds = program.duration.inSeconds;
    final minutes = (seconds / 60).ceil().clamp(1, 24 * 60);
    setState(() {
      selectedProgram = program;
      customDuration = false;
      if (seconds > 0) {
        selectedMinutes = minutes;
        remainingSeconds = seconds;
      }
    });
  }

  Future<Duration?> _startBackgroundAudio() async {
    final program = selectedProgram;
    final audioUrl = program?.audioUrl;
    if (program == null || audioUrl == null || audioUrl.trim().isEmpty) {
      return null;
    }
    final player = backgroundPlayer ??= AudioPlayer();
    final source = await ref
        .read(mediaDownloadsProvider.notifier)
        .sourceFor(mediaKey('meditation', program.id), audioUrl);
    if (source == audioUrl) {
      await player.setUrl(source);
    } else {
      await player.setFilePath(source);
    }
    final detectedDuration =
        player.duration ??
        await player.durationStream
            .firstWhere((value) => value != null && value.inSeconds > 0)
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
    await player.setLoopMode(LoopMode.off);
    await player.play();
    return detectedDuration;
  }
}

class _EmptyMeditationProgram extends StatelessWidget {
  const _EmptyMeditationProgram();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.self_improvement),
        title: Text('Chưa có bài Thiền'),
      ),
    );
  }
}

class _ProgramChooser extends ConsumerWidget {
  const _ProgramChooser({
    required this.programs,
    required this.selectedProgramId,
    required this.enabled,
    required this.onSelected,
  });

  final List<MeditationProgram> programs;
  final String? selectedProgramId;
  final bool enabled;
  final ValueChanged<MeditationProgram> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final program in programs)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChoiceChip(
                  label: Text(program.title),
                  selected: selectedProgramId == program.id,
                  onSelected: enabled ? (_) => onSelected(program) : null,
                ),
                if (program.audioUrl?.trim().isNotEmpty == true)
                  MediaDownloadButton(
                    mediaKey: mediaKey('meditation', program.id),
                    title: program.title,
                    url: program.audioUrl!,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
