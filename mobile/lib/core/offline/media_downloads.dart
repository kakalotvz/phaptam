import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';

final mediaDownloadsProvider =
    AsyncNotifierProvider<MediaDownloadController, MediaDownloadState>(
      MediaDownloadController.new,
    );
final downloadManifestProvider = FutureProvider<List<RemoteDownload>>((
  ref,
) async {
  if (apiClient.accessToken == null) return const [];
  final items = await apiClient.getList('/me/downloads');
  return items
      .cast<Map<String, dynamic>>()
      .map(RemoteDownload.fromJson)
      .toList();
});

const _restorePromptStorage = FlutterSecureStorage();

class MediaDownloadState {
  const MediaDownloadState({required this.items, this.progress = const {}});

  final Map<String, DownloadedMedia> items;
  final Map<String, double> progress;

  bool isDownloaded(String key) => items.containsKey(key);
  bool isDownloading(String key) => progress.containsKey(key);

  String? localPath(String key) => items[key]?.path;

  MediaDownloadState copyWith({
    Map<String, DownloadedMedia>? items,
    Map<String, double>? progress,
  }) {
    return MediaDownloadState(
      items: items ?? this.items,
      progress: progress ?? this.progress,
    );
  }
}

class DownloadedMedia {
  const DownloadedMedia({
    required this.key,
    required this.title,
    required this.url,
    required this.path,
    required this.downloadedAt,
  });

  final String key;
  final String title;
  final String url;
  final String path;
  final DateTime downloadedAt;

  factory DownloadedMedia.fromJson(Map<String, dynamic> json) {
    return DownloadedMedia(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      path: json['path'] as String? ?? '',
      downloadedAt:
          DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'title': title,
      'url': url,
      'path': path,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }
}

class RemoteDownload {
  const RemoteDownload({
    required this.mediaKey,
    required this.mediaType,
    required this.contentId,
    required this.title,
    required this.url,
    this.thumbnailUrl,
  });

  factory RemoteDownload.fromJson(Map<String, dynamic> json) {
    return RemoteDownload(
      mediaKey: json['mediaKey'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? '',
      contentId: json['contentId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  final String mediaKey;
  final String mediaType;
  final String contentId;
  final String title;
  final String url;
  final String? thumbnailUrl;
}

class MediaDownloadController extends AsyncNotifier<MediaDownloadState> {
  @override
  Future<MediaDownloadState> build() async {
    return MediaDownloadState(items: await _readIndex());
  }

  Future<String> sourceFor(String key, String onlineUrl) async {
    final current = state.value ?? await future;
    final localPath = current.localPath(key);
    if (localPath != null && await File(localPath).exists()) return localPath;
    return onlineUrl;
  }

  Future<void> download({
    required String key,
    required String title,
    required String url,
    String? thumbnailUrl,
  }) async {
    if (url.trim().isEmpty) return;
    if (apiClient.accessToken == null) {
      throw Exception('Bạn cần đăng nhập để tải nội dung dùng offline');
    }
    final current = state.value ?? await future;
    if (current.isDownloaded(key) || current.isDownloading(key)) return;

    final directory = await _mediaDirectory();
    final extension = _extensionFor(url);
    final target = File('${directory.path}/${_safeFileName(key)}.$extension');
    final temp = File('${target.path}.download');
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final progress = Map<String, double>.from(current.progress)..[key] = 0;
    state = AsyncData(current.copyWith(progress: progress));

    final sink = temp.openWrite();
    var received = 0;
    final total = response.contentLength ?? 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        final latest = state.value ?? current;
        state = AsyncData(
          latest.copyWith(
            progress: {
              ...latest.progress,
              key: total > 0 ? received / total : 0,
            },
          ),
        );
      }
    } finally {
      await sink.close();
    }

    if (await target.exists()) await target.delete();
    await temp.rename(target.path);

    final latest = state.value ?? current;
    final items = Map<String, DownloadedMedia>.from(latest.items)
      ..[key] = DownloadedMedia(
        key: key,
        title: title,
        url: url,
        path: target.path,
        downloadedAt: DateTime.now(),
      );
    final nextProgress = Map<String, double>.from(latest.progress)..remove(key);
    await _writeIndex(items);
    state = AsyncData(MediaDownloadState(items: items, progress: nextProgress));
    await _syncRemoteDownload(
      key: key,
      title: title,
      url: url,
      thumbnailUrl: thumbnailUrl,
    );
  }

  Future<void> remove(String key) async {
    final current = state.value ?? await future;
    final item = current.items[key];
    if (item == null) return;
    final file = File(item.path);
    if (await file.exists()) await file.delete();
    final items = Map<String, DownloadedMedia>.from(current.items)..remove(key);
    await _writeIndex(items);
    state = AsyncData(current.copyWith(items: items));
  }

  Future<void> _syncRemoteDownload({
    required String key,
    required String title,
    required String url,
    String? thumbnailUrl,
  }) async {
    final parts = _partsForKey(key);
    if (parts == null || apiClient.accessToken == null) return;
    await apiClient.post('/me/downloads', {
      'mediaKey': key,
      'mediaType': parts.$1,
      'contentId': parts.$2,
      'title': title,
      'url': url,
      if (thumbnailUrl?.trim().isNotEmpty == true) 'thumbnailUrl': thumbnailUrl,
    });
  }

  Future<Map<String, DownloadedMedia>> _readIndex() async {
    final file = await _indexFile();
    if (!await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) return {};
    final entries = decoded
        .whereType<Map<String, dynamic>>()
        .map(DownloadedMedia.fromJson)
        .where((item) => item.key.isNotEmpty && File(item.path).existsSync());
    return {for (final item in entries) item.key: item};
  }

  Future<void> _writeIndex(Map<String, DownloadedMedia> items) async {
    final file = await _indexFile();
    await file.writeAsString(
      jsonEncode(items.values.map((item) => item.toJson()).toList()),
    );
  }

  Future<File> _indexFile() async {
    final directory = await _mediaDirectory();
    return File('${directory.path}/downloads.json');
  }

  Future<Directory> _mediaDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/offline_media');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }
}

String mediaKey(String type, String id) => '$type:$id';

(String, String)? _partsForKey(String key) {
  final separator = key.indexOf(':');
  if (separator <= 0 || separator == key.length - 1) return null;
  return (key.substring(0, separator), key.substring(separator + 1));
}

Future<bool> shouldPromptDownloadRestore(
  List<RemoteDownload> remoteItems,
  MediaDownloadState localState,
) async {
  final userId = apiClient.currentUserId;
  if (userId == null || userId.isEmpty) return false;
  final seen = await _restorePromptStorage.read(
    key: 'download_restore_prompt_seen_$userId',
  );
  if (seen == '1') return false;
  return remoteItems.any((item) => !localState.isDownloaded(item.mediaKey));
}

Future<void> markDownloadRestorePromptSeen() async {
  final userId = apiClient.currentUserId;
  if (userId == null || userId.isEmpty) return;
  await _restorePromptStorage.write(
    key: 'download_restore_prompt_seen_$userId',
    value: '1',
  );
}

String _safeFileName(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}

String _extensionFor(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  final parts = path.split('.');
  final extension = parts.isEmpty ? null : parts.last;
  if (extension == 'mp3' || extension == 'mp4' || extension == 'webp') {
    return extension ?? 'mp3';
  }
  return path.contains('video') ? 'mp4' : 'mp3';
}
