import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'content_models.dart';

final audioCategoriesProvider = FutureProvider<List<AudioCategory>>((
  ref,
) async {
  final items = await apiClient.getList('/categories/audio');
  return items
      .cast<Map<String, dynamic>>()
      .map(AudioCategory.fromJson)
      .where((item) => item.name.trim().isNotEmpty)
      .toList();
});

final audioListProvider = FutureProvider<List<AudioItem>>((ref) async {
  final items = await apiClient.getList('/audio');
  return items
      .cast<Map<String, dynamic>>()
      .map(AudioItem.fromJson)
      .where(
        (item) =>
            item.title.trim().isNotEmpty && item.audioUrl.trim().isNotEmpty,
      )
      .toList();
});

final videoListProvider = FutureProvider<List<VideoItem>>((ref) async {
  final items = await apiClient.getList('/video');
  return items
      .cast<Map<String, dynamic>>()
      .map(VideoItem.fromJson)
      .where(
        (item) =>
            item.title.trim().isNotEmpty && item.videoUrl.trim().isNotEmpty,
      )
      .toList();
});

final newsListProvider = FutureProvider<List<NewsItem>>((ref) async {
  final items = await apiClient.getList('/news');
  return items
      .cast<Map<String, dynamic>>()
      .map(NewsItem.fromJson)
      .where((item) => item.title.trim().isNotEmpty)
      .toList();
});

final meditationProgramsProvider = FutureProvider<List<MeditationProgram>>((
  ref,
) async {
  final items = await apiClient.getList('/meditation');
  return items
      .cast<Map<String, dynamic>>()
      .map(MeditationProgram.fromJson)
      .where(
        (item) => item.title.trim().isNotEmpty && item.duration.inSeconds > 0,
      )
      .toList();
});

final dailyQuotesProvider = FutureProvider<List<DailyQuote>>((ref) async {
  final items = await apiClient.getList('/quotes');
  return items
      .cast<Map<String, dynamic>>()
      .map(DailyQuote.fromJson)
      .where((item) => item.content.trim().isNotEmpty)
      .toList();
});

final homeBannersProvider = FutureProvider<List<HomeBanner>>((ref) async {
  final items = await apiClient.getList('/banners');
  return items
      .cast<Map<String, dynamic>>()
      .map(HomeBanner.fromJson)
      .where((item) => item.imageUrl.trim().isNotEmpty)
      .toList();
});

final scriptureListProvider = FutureProvider<List<Scripture>>((ref) async {
  final items = await apiClient.getList('/scriptures');
  final remoteScriptures = items
      .cast<Map<String, dynamic>>()
      .map(Scripture.fromJson)
      .where((item) => item.lines.isNotEmpty)
      .toList();
  return remoteScriptures;
});

final scriptureReminderProvider =
    NotifierProvider<ScriptureReminderState, List<ScriptureReminder>>(
      ScriptureReminderState.new,
    );

class ScriptureReminderState extends Notifier<List<ScriptureReminder>> {
  @override
  List<ScriptureReminder> build() {
    return const [];
  }

  void add({
    required String title,
    required Scripture scripture,
    required Duration timeOfDay,
    required Set<int> weekdays,
    required ReminderResumeMode resumeMode,
  }) {
    state = [
      ScriptureReminder(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        scripture: scripture,
        timeOfDay: timeOfDay,
        weekdays: weekdays,
        resumeMode: resumeMode,
      ),
      ...state,
    ];
  }

  void toggle(String id, bool active) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(active: active) else item,
    ];
  }

  void saveProgress(String id, int lineIndex) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(lastLineIndex: lineIndex) else item,
    ];
  }
}

final selectedAudioCategoryProvider =
    NotifierProvider<SelectedAudioCategory, String?>(SelectedAudioCategory.new);

class SelectedAudioCategory extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? value) => state = value;
}

final filteredAudioProvider = Provider<List<AudioItem>>((ref) {
  final selected = ref.watch(selectedAudioCategoryProvider);
  final items =
      ref.watch(audioListProvider).whenOrNull(data: (value) => value) ??
      const [];
  if (selected == null) return items;
  return items.where((item) => item.category == selected).toList();
});

final isLoggedInProvider = NotifierProvider<LoginState, bool>(LoginState.new);
final darkModeProvider = NotifierProvider<DarkModeState, bool>(
  DarkModeState.new,
);

class LoginState extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void login() => state = true;
  void logout() => state = false;
}

class DarkModeState extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool value) => state = value;
}
