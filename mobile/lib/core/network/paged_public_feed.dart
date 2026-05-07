import 'package:flutter/foundation.dart';

import 'api_client.dart';

class PagedPublicFeed<T> extends ChangeNotifier {
  PagedPublicFeed({
    required this.path,
    required this.fromJson,
    required this.isValid,
    this.pageSize = 10,
  });

  final String path;
  final T Function(Map<String, dynamic> json) fromJson;
  final bool Function(T item) isValid;
  final int pageSize;

  final List<T> _items = <T>[];
  int _page = 0;
  bool _hasMore = true;
  bool _initialized = false;
  bool _loadingInitial = false;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _loadingAll = false;
  Object? _error;

  List<T> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get initialized => _initialized;
  bool get loadingInitial => _loadingInitial;
  bool get loadingMore => _loadingMore;
  bool get refreshing => _refreshing;
  bool get loadingAll => _loadingAll;
  bool get busy =>
      _loadingInitial || _loadingMore || _refreshing || _loadingAll;
  Object? get error => _error;

  Future<void> loadInitial() async {
    if (_initialized || _loadingInitial) return;
    _loadingInitial = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _fetchPage(1);
      _items
        ..clear()
        ..addAll(page.items);
      _page = 1;
      _hasMore = page.hasMore;
      _initialized = true;
    } catch (error) {
      _error = error;
    } finally {
      _loadingInitial = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _fetchPage(1);
      _items
        ..clear()
        ..addAll(page.items);
      _page = 1;
      _hasMore = page.hasMore;
      _initialized = true;
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!_initialized || !_hasMore || _loadingMore || _refreshing) return;
    _loadingMore = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _fetchPage(_page + 1);
      _items.addAll(page.items);
      _page += 1;
      _hasMore = page.hasMore;
    } catch (error) {
      _error = error;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> ensureAllLoaded() async {
    if (_loadingAll || !_initialized || !_hasMore) return;
    _loadingAll = true;
    notifyListeners();
    try {
      while (_hasMore) {
        await loadMore();
        if (_error != null) break;
      }
    } finally {
      _loadingAll = false;
      notifyListeners();
    }
  }

  Future<_PagedResult<T>> _fetchPage(int page) async {
    final payload = await apiClient.getMap(
      path,
      queryParameters: {'page': page, 'limit': pageSize},
    );
    final rawItems = payload['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(fromJson)
              .where(isValid)
              .toList()
        : <T>[];
    final hasMore = payload['hasMore'] as bool? ?? items.length >= pageSize;
    return _PagedResult(items: items, hasMore: hasMore);
  }
}

class _PagedResult<T> {
  const _PagedResult({required this.items, required this.hasMore});

  final List<T> items;
  final bool hasMore;
}
