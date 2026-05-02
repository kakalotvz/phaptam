import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

final mediaDownloadsProvider =
    AsyncNotifierProvider<MediaDownloadController, MediaDownloadState>(
      MediaDownloadController.new,
    );

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
  }) async {
    if (url.trim().isEmpty) return;
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
