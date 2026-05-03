import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

class PublicListCache {
  const PublicListCache._();

  static const refreshAfter = Duration(minutes: 2);

  static Future<List<dynamic>> getList(
    Ref ref,
    String path, {
    bool refreshInBackground = true,
  }) async {
    final entry = await _read(path);
    if (entry != null) {
      if (refreshInBackground && entry.isStale) {
        unawaited(
          _refresh(path).then((updated) {
            if (updated) ref.invalidateSelf();
          }),
        );
      }
      return entry.items;
    }

    final items = await apiClient.getList(path);
    await _write(path, items);
    return items;
  }

  static Future<bool> refresh(String path) => _refresh(path);

  static Future<bool> _refresh(String path) async {
    try {
      final items = await apiClient.getList(path);
      await _write(path, items);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<_CacheEntry?> _read(String path) async {
    final file = await _file(path);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final items = decoded['items'];
      if (items is! List) return null;
      final fetchedAt =
          DateTime.tryParse(decoded['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return _CacheEntry(items: items, fetchedAt: fetchedAt);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String path, List<dynamic> items) async {
    final file = await _file(path);
    if (!await file.parent.exists()) await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'fetchedAt': DateTime.now().toIso8601String(),
        'items': items,
      }),
    );
  }

  static Future<File> _file(String path) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/public_cache');
    return File('${directory.path}/${_safeName(path)}.json');
  }
}

class _CacheEntry {
  const _CacheEntry({required this.items, required this.fetchedAt});

  final List<dynamic> items;
  final DateTime fetchedAt;

  bool get isStale =>
      DateTime.now().difference(fetchedAt) > PublicListCache.refreshAfter;
}

String _safeName(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
