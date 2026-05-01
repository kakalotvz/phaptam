import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final scriptureListProvider = Provider<List<Scripture>>(
  (ref) => ref.watch(contentRepositoryProvider).scriptures,
);

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
