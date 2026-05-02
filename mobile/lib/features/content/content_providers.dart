import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'content_models.dart';
import 'content_repository.dart';

final contentRepositoryProvider = Provider((ref) => ContentRepository());

final audioCategoriesProvider = Provider<List<AudioCategory>>(
  (ref) => ref.watch(contentRepositoryProvider).audioCategories,
);

final audioListProvider = Provider<List<AudioItem>>(
  (ref) => ref.watch(contentRepositoryProvider).audios,
);

final videoListProvider = Provider<List<VideoItem>>(
  (ref) => ref.watch(contentRepositoryProvider).videos,
);

final newsListProvider = Provider<List<NewsItem>>(
  (ref) => ref.watch(contentRepositoryProvider).news,
);

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

final scriptureListProvider = Provider<List<Scripture>>(
  (ref) => ref.watch(contentRepositoryProvider).scriptures,
);

final scriptureReminderProvider =
    NotifierProvider<ScriptureReminderState, List<ScriptureReminder>>(
      ScriptureReminderState.new,
    );

class ScriptureReminderState extends Notifier<List<ScriptureReminder>> {
  @override
  List<ScriptureReminder> build() {
    final scriptures = ref.watch(scriptureListProvider);
    if (scriptures.isEmpty) return const [];
    return [
      ScriptureReminder(
        id: 'r1',
        title: 'Công phu sáng',
        scripture: scriptures.first,
        timeOfDay: const Duration(hours: 5, minutes: 30),
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        resumeMode: ReminderResumeMode.resume,
      ),
    ];
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
  final items = ref.watch(audioListProvider);
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
