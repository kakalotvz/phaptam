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
  bool listenFullAudio = false;
  bool isStarting = false;
  int customValue = 20;
  String customUnit = 'minutes';
  Timer? timer;
  AudioPlayer? backgroundPlayer;
  MeditationProgram? selectedProgram;
  String? loadedProgramId;

  bool get isRunning => timer != null;

  @override
  void dispose() {
    timer?.cancel();
    backgroundPlayer?.dispose();
    super.dispose();
  }

  Future<void> toggle() async {
    if (isStarting) return;
    if (isRunning) {
      timer?.cancel();
      setState(() => timer = null);
      await backgroundPlayer?.pause();
      return;
    }

    setState(() => isStarting = true);
    try {
      final detectedDuration = await _prepareBackgroundAudio(
        detectDuration: listenFullAudio,
      );
      if (listenFullAudio) {
        final detectedSeconds = detectedDuration?.inSeconds ?? 0;
        if (detectedSeconds > 0) {
          selectedMinutes = (detectedSeconds / 60).ceil();
          remainingSeconds = detectedSeconds;
        }
      }
      if (remainingSeconds <= 0) remainingSeconds = selectedMinutes * 60;

      unawaited(
        (backgroundPlayer?.play() ?? Future<void>.value()).catchError((_) {}),
      );
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (remainingSeconds <= 1) {
          timer?.cancel();
          unawaited(_stopBackgroundAudio(resetPosition: true));
          setState(() {
            timer = null;
            remainingSeconds = selectedMinutes * 60;
          });
        } else {
          setState(() => remainingSeconds--);
        }
      });
    } finally {
      if (mounted) setState(() => isStarting = false);
    }
  }

  Future<void> stopMeditation() async {
    timer?.cancel();
    await _stopBackgroundAudio(resetPosition: true);
    if (!mounted) return;
    setState(() {
      timer = null;
      isStarting = false;
      remainingSeconds = selectedMinutes * 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final programs = ref.watch(meditationProgramsProvider);
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (selectedProgram?.imageUrl?.trim().isNotEmpty == true)
            Image.network(
              selectedProgram!.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF121212).withValues(
                alpha: selectedProgram?.imageUrl?.trim().isNotEmpty == true
                    ? .68
                    : 1,
              ),
            ),
          ),
          SafeArea(
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
                                      !listenFullAudio &&
                                      !customDuration &&
                                      selectedMinutes == value,
                                  onSelected: isRunning
                                      ? null
                                      : (_) => setState(() {
                                          listenFullAudio = false;
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
                                        listenFullAudio = false;
                                        customDuration = true;
                                        _applyCustomDuration();
                                      }),
                              ),
                              ChoiceChip(
                                label: const Text('Nghe hết âm thanh nền'),
                                selected: listenFullAudio,
                                onSelected:
                                    isRunning ||
                                        selectedProgram?.audioUrl
                                                ?.trim()
                                                .isNotEmpty !=
                                            true
                                    ? null
                                    : (_) => setState(() {
                                        listenFullAudio = true;
                                        customDuration = false;
                                        final seconds =
                                            selectedProgram!.duration.inSeconds;
                                        if (seconds > 0) {
                                          selectedMinutes = (seconds / 60)
                                              .ceil();
                                          remainingSeconds = seconds;
                                        }
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
                                      labelStyle: TextStyle(
                                        color: Colors.white70,
                                      ),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: isStarting
                                    ? null
                                    : () => unawaited(toggle()),
                                icon: Icon(
                                  isRunning ? Icons.pause : Icons.play_arrow,
                                ),
                                label: Text(
                                  isStarting
                                      ? 'Đang mở'
                                      : isRunning
                                      ? 'Tạm dừng'
                                      : 'Bắt đầu',
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton.filledTonal(
                                tooltip: 'Dừng hẳn',
                                onPressed:
                                    isStarting ||
                                        (!isRunning &&
                                            remainingSeconds ==
                                                selectedMinutes * 60)
                                    ? null
                                    : () => unawaited(stopMeditation()),
                                icon: const Icon(Icons.stop),
                              ),
                            ],
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
        ],
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
    setState(() {
      selectedProgram = program;
      if (listenFullAudio && seconds > 0) {
        selectedMinutes = (seconds / 60).ceil();
        remainingSeconds = seconds;
      }
    });
  }

  Future<Duration?> _prepareBackgroundAudio({
    required bool detectDuration,
  }) async {
    final program = selectedProgram;
    final audioUrl = program?.audioUrl;
    if (program == null || audioUrl == null || audioUrl.trim().isEmpty) {
      return null;
    }
    final player = backgroundPlayer ??= AudioPlayer();
    final source = await ref
        .read(mediaDownloadsProvider.notifier)
        .sourceFor(mediaKey('meditation', program.id), audioUrl);
    if (loadedProgramId != program.id) {
      if (source == audioUrl) {
        await player.setUrl(source);
      } else {
        await player.setFilePath(source);
      }
      loadedProgramId = program.id;
    }
    await player.setLoopMode(LoopMode.off);
    if (!detectDuration) return player.duration;
    final detectedDuration =
        player.duration ??
        await player.durationStream
            .firstWhere((value) => value != null && value.inSeconds > 0)
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
    return detectedDuration;
  }

  Future<void> _stopBackgroundAudio({required bool resetPosition}) async {
    final player = backgroundPlayer;
    if (player == null) return;
    if (resetPosition && loadedProgramId != null) {
      await player.seek(Duration.zero);
    }
    await player.stop();
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
      child: Column(
        spacing: 8,
        children: [
          for (final program in programs)
            Card(
              color: selectedProgramId == program.id
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
              child: ListTile(
                enabled: enabled,
                contentPadding: const EdgeInsets.only(left: 14, right: 6),
                leading: Icon(
                  selectedProgramId == program.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(program.title, maxLines: 3),
                subtitle: program.description?.trim().isNotEmpty == true
                    ? Text(program.description!, maxLines: 2)
                    : null,
                onTap: enabled ? () => onSelected(program) : null,
                trailing: program.audioUrl?.trim().isNotEmpty == true
                    ? MediaDownloadButton(
                        mediaKey: mediaKey('meditation', program.id),
                        title: program.title,
                        url: program.audioUrl!,
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
