import 'dart:async';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';

class AppPresenceService {
  AppPresenceService._();

  static final instance = AppPresenceService._();
  static const _storage = FlutterSecureStorage();
  static const _clientIdKey = 'phaptam_presence_client_id';
  static const _heartbeatInterval = Duration(seconds: 15);

  Timer? _timer;
  String? _clientId;
  bool _sending = false;

  Future<void> start() async {
    _clientId ??= await _resolveClientId();
    await _heartbeat();
    _timer ??= Timer.periodic(_heartbeatInterval, (_) => unawaited(_heartbeat()));
  }

  Future<void> stop({bool sendLeave = true}) async {
    _timer?.cancel();
    _timer = null;

    if (!sendLeave) return;
    final clientId = _clientId ?? await _resolveClientId();
    try {
      await apiClient.post('/presence/leave', {'clientId': clientId});
    } catch (_) {
      // Presence is best-effort; TTL on the backend will clear stale sessions.
    }
  }

  Future<void> _heartbeat() async {
    if (_sending) return;
    _sending = true;
    try {
      final clientId = _clientId ?? await _resolveClientId();
      await apiClient.post('/presence/heartbeat', {'clientId': clientId});
    } catch (_) {
      // Ignore transient network failures so presence never blocks the app.
    } finally {
      _sending = false;
    }
  }

  Future<String> _resolveClientId() async {
    final existing = await _storage.read(key: _clientIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final clientId = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _clientIdKey, value: clientId);
    return clientId;
  }
}
