import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../network/api_client.dart';

final biometricAuthProvider =
    AsyncNotifierProvider<BiometricAuthController, BiometricAuthState>(
      BiometricAuthController.new,
    );

class BiometricAuthState {
  const BiometricAuthState({
    required this.supported,
    required this.enabled,
    required this.label,
    this.savedUserId,
  });

  final bool supported;
  final bool enabled;
  final String label;
  final String? savedUserId;

  bool get enabledForCurrentUser =>
      enabled &&
      savedUserId != null &&
      savedUserId!.isNotEmpty &&
      savedUserId == apiClient.currentUserId;
}

class BiometricAuthController extends AsyncNotifier<BiometricAuthState> {
  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'phaptam_biometric_enabled';
  static const _tokenKey = 'phaptam_biometric_token';
  static const _userIdKey = 'phaptam_biometric_user_id';

  final _auth = LocalAuthentication();

  @override
  Future<BiometricAuthState> build() async {
    final supported = await _isSupported();
    final savedUserId = await _storage.read(key: _userIdKey);
    final enabled =
        await _storage.read(key: _enabledKey) == '1' &&
        (await _storage.read(key: _tokenKey))?.isNotEmpty == true &&
        savedUserId?.isNotEmpty == true;
    return BiometricAuthState(
      supported: supported,
      enabled: supported && enabled,
      label: await _label(),
      savedUserId: savedUserId,
    );
  }

  Future<void> enableForCurrentSession() async {
    final token = apiClient.accessToken;
    final userId = apiClient.currentUserId;
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      throw Exception('Bạn cần đăng nhập trước khi bật sinh trắc học');
    }

    final ok = await _authenticate(
      'Xác nhận sinh trắc học để bật đăng nhập nhanh trên thiết bị này',
    );
    if (!ok) throw Exception('Chưa xác nhận sinh trắc học');

    await _storage.write(key: _enabledKey, value: '1');
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    ref.invalidateSelf();
  }

  Future<void> refreshCredentialForCurrentSession() async {
    final token = apiClient.accessToken;
    final userId = apiClient.currentUserId;
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      return;
    }

    final enabled = await _storage.read(key: _enabledKey) == '1';
    final savedUserId = await _storage.read(key: _userIdKey);
    if (!enabled || savedUserId != userId) return;

    await _storage.write(key: _tokenKey, value: token);
    ref.invalidateSelf();
  }

  Future<void> disable() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    ref.invalidateSelf();
  }

  Future<void> restoreSession() async {
    final current = state.value ?? await future;
    if (!current.supported || !current.enabled) {
      throw Exception('Thiết bị chưa bật đăng nhập bằng sinh trắc học');
    }

    final ok = await _authenticate('Đăng nhập Pháp Tâm bằng ${current.label}');
    if (!ok) throw Exception('Không thể xác nhận sinh trắc học');

    final token = await _storage.read(key: _tokenKey);
    final userId = await _storage.read(key: _userIdKey);
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      await disable();
      throw Exception('Phiên sinh trắc học không còn hợp lệ');
    }

    await apiClient.saveSession(token: token, userId: userId);
  }

  Future<bool> _isSupported() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<String> _label() async {
    try {
      final methods = await _auth.getAvailableBiometrics();
      if (methods.contains(BiometricType.face)) return 'Face ID';
      if (methods.contains(BiometricType.fingerprint)) return 'vân tay';
      if (methods.isNotEmpty) return 'sinh trắc học';
    } catch (_) {
      // Fall through to a neutral label.
    }
    return 'sinh trắc học';
  }

  Future<bool> _authenticate(String reason) {
    return _auth.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}
