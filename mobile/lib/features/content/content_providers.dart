import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/public_cache.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/offline/media_downloads.dart';
import 'content_models.dart';

final audioCategoriesProvider = FutureProvider<List<AudioCategory>>((
  ref,
) async {
  _refreshPeriodically(ref);
  final items = await PublicListCache.getList(ref, '/categories/audio');
  return items
      .cast<Map<String, dynamic>>()
      .map(AudioCategory.fromJson)
      .where((item) => item.name.trim().isNotEmpty)
      .toList();
});

final audioListProvider = FutureProvider<List<AudioItem>>((ref) async {
  _refreshPeriodically(ref);
  final items = await PublicListCache.getList(ref, '/audio');
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
  _refreshPeriodically(ref);
  final items = await PublicListCache.getList(ref, '/video');
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
  _refreshPeriodically(ref);
  final items = await PublicListCache.getList(ref, '/news');
  return items
      .cast<Map<String, dynamic>>()
      .map(NewsItem.fromJson)
      .where((item) => item.title.trim().isNotEmpty)
      .toList();
});

final meditationProgramsProvider = FutureProvider<List<MeditationProgram>>((
  ref,
) async {
  _refreshPeriodically(ref);
  final items = await PublicListCache.getList(ref, '/meditation');
  return items
      .cast<Map<String, dynamic>>()
      .map(MeditationProgram.fromJson)
      .where((item) => item.title.trim().isNotEmpty)
      .toList();
});

final dailyQuotesProvider = FutureProvider<List<DailyQuote>>((ref) async {
  _refreshPeriodically(ref);
  final items = await PublicListCache.getList(ref, '/quotes');
  return items
      .cast<Map<String, dynamic>>()
      .map(DailyQuote.fromJson)
      .where((item) => item.content.trim().isNotEmpty)
      .toList();
});

final homeBannersProvider = FutureProvider<List<HomeBanner>>((ref) async {
  _refreshPeriodically(ref);
  final items = await PublicListCache.getList(ref, '/banners');
  return items
      .cast<Map<String, dynamic>>()
      .map(HomeBanner.fromJson)
      .where((item) => item.imageUrl.trim().isNotEmpty)
      .toList();
});

final scriptureListProvider = FutureProvider<List<Scripture>>((ref) async {
  _refreshPeriodically(ref);
  final items = await PublicListCache.getList(ref, '/scriptures');
  final remoteScriptures = items
      .cast<Map<String, dynamic>>()
      .map(Scripture.fromJson)
      .where((item) => item.title.trim().isNotEmpty)
      .toList();
  return remoteScriptures;
});

const publicCachePaths = [
  '/categories/audio',
  '/audio',
  '/video',
  '/news',
  '/meditation',
  '/quotes',
  '/banners',
  '/scriptures',
];

Future<void> refreshPublicContent(WidgetRef ref) async {
  await Future.wait(publicCachePaths.map(PublicListCache.refresh));
  ref.invalidate(audioCategoriesProvider);
  ref.invalidate(audioListProvider);
  ref.invalidate(videoListProvider);
  ref.invalidate(newsListProvider);
  ref.invalidate(meditationProgramsProvider);
  ref.invalidate(dailyQuotesProvider);
  ref.invalidate(homeBannersProvider);
  ref.invalidate(scriptureListProvider);
  ref.invalidate(scriptureReminderProvider);
}

void _refreshPeriodically(Ref ref) {
  final timer = Timer(const Duration(minutes: 5), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
}

final scriptureReminderProvider =
    AsyncNotifierProvider<ScriptureReminderState, List<ScriptureReminder>>(
      ScriptureReminderState.new,
    );

class ScriptureReminderState extends AsyncNotifier<List<ScriptureReminder>> {
  @override
  Future<List<ScriptureReminder>> build() async {
    if (apiClient.accessToken == null) return const [];
    final items = await apiClient.getList('/me/scripture-reminders');
    final reminders = items
        .cast<Map<String, dynamic>>()
        .map(ScriptureReminder.fromJson)
        .where((item) => item.scripture.id.isNotEmpty)
        .toList();
    await NotificationService.instance.syncScriptureReminders(reminders);
    return reminders;
  }

  Future<void> add({
    required String title,
    required Scripture scripture,
    required Duration timeOfDay,
    required Set<int> weekdays,
    required ReminderResumeMode resumeMode,
  }) async {
    final created = await apiClient.post('/me/scripture-reminders', {
      'title': title,
      'scriptureId': scripture.id,
      'timeOfDay': _formatReminderTime(timeOfDay),
      'weekdays': weekdays.toList()..sort(),
      'resumeMode': resumeMode == ReminderResumeMode.restart
          ? 'RESTART'
          : 'RESUME',
      'active': true,
    });
    final current = state.value ?? const <ScriptureReminder>[];
    final next = <ScriptureReminder>[
      ScriptureReminder.fromJson(created),
      ...current,
    ];
    state = AsyncData(next);
    await NotificationService.instance.syncScriptureReminders(next);
  }

  Future<void> toggle(String id, bool active) async {
    await apiClient.patch('/me/scripture-reminders/$id', {'active': active});
    final next = [
      for (final item in state.value ?? const <ScriptureReminder>[])
        if (item.id == id) item.copyWith(active: active) else item,
    ];
    state = AsyncData(next);
    await NotificationService.instance.syncScriptureReminders(next);
  }

  Future<void> saveProgress(String id, int lineIndex) async {
    final current = state.value ?? const <ScriptureReminder>[];
    final next = [
      for (final item in current)
        if (item.id == id) item.copyWith(lastLineIndex: lineIndex) else item,
    ];
    state = AsyncData(next);
    await apiClient.patch('/me/scripture-reminders/$id', {
      'lastLineIndex': lineIndex,
    });
  }
}

String _formatReminderTime(Duration value) {
  final hour = value.inHours.remainder(24).toString().padLeft(2, '0');
  final minute = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '$hour:$minute';
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
  bool build() => apiClient.accessToken != null;

  void toggle() => state = !state;
  void login() => state = true;
  Future<void> logout() async {
    await apiClient.clearSession();
    state = false;
    ref.invalidate(downloadManifestProvider);
    ref.invalidate(scriptureReminderProvider);
  }
}

class DarkModeState extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool value) => state = value;
}
