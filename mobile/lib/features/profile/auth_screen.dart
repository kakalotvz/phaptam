import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../content/content_providers.dart';

enum AuthMode { login, register, forgot }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({required this.mode, super.key});

  final AuthMode mode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final birthDateController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool acceptedTerms = false;
  bool submitting = false;

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    birthDateController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  String get title => switch (widget.mode) {
        AuthMode.login => 'Đăng nhập',
        AuthMode.register => 'Đăng ký',
        AuthMode.forgot => 'Quên mật khẩu',
      };

  @override
  Widget build(BuildContext context) {
    final isRegister = widget.mode == AuthMode.register;
    final isForgot = widget.mode == AuthMode.forgot;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Icon(
            isForgot ? Icons.lock_reset : Icons.account_circle_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            isForgot
                ? 'Nhập email để nhận hướng dẫn đặt lại mật khẩu.'
                : isRegister
                    ? 'Tạo tài khoản để lưu yêu thích, playlist và tiến trình nghe.'
                    : 'Đăng nhập để tiếp tục hành trình tu học của bạn.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 28),
          if (isRegister) ...[
            TextField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Họ tên',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: birthDateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Ngày tháng năm sinh',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
              onTap: _pickBirthDate,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tài khoản',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          if (!isForgot) ...[
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              obscureText: true,
              textInputAction: isRegister ? TextInputAction.next : TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
          if (isRegister) ...[
            const SizedBox(height: 14),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: acceptedTerms,
              onChanged: (value) => setState(() => acceptedTerms = value ?? false),
              title: const Text('Tôi đồng ý với điều khoản sử dụng'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: submitting ? null : _submit,
            icon: Icon(isForgot ? Icons.send_outlined : Icons.login),
            label: Text(submitting ? 'Đang xử lý...' : isForgot ? 'Gửi hướng dẫn' : title),
          ),
          const SizedBox(height: 12),
          if (widget.mode == AuthMode.login)
            TextButton(
              onPressed: () => context.push('/forgot-password'),
              child: const Text('Quên mật khẩu?'),
            ),
          if (widget.mode == AuthMode.login)
            OutlinedButton.icon(
              onPressed: () => context.push('/register'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Tạo tài khoản mới'),
            ),
          if (widget.mode == AuthMode.register)
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Đã có tài khoản? Đăng nhập'),
            ),
        ],
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDate: DateTime(1990),
    );
    if (picked == null) return;
    birthDateController.text = picked.toIso8601String().split('T').first;
  }

  Future<void> _submit() async {
    setState(() => submitting = true);
    try {
      if (widget.mode == AuthMode.forgot) {
        await apiClient.post('/auth/forgot-password', {'email': emailController.text.trim()});
      } else if (widget.mode == AuthMode.register) {
        if (passwordController.text != confirmController.text) {
          throw Exception('Mật khẩu nhập lại không khớp');
        }
        final body = <String, dynamic>{
          'email': emailController.text.trim(),
          'username': usernameController.text.trim(),
          'name': nameController.text.trim(),
          'password': passwordController.text,
          'acceptedTerms': acceptedTerms,
        };
        if (birthDateController.text.trim().isNotEmpty) {
          body['birthDate'] = birthDateController.text.trim();
        }
        final result = await apiClient.post('/auth/register', body);
        apiClient.accessToken = result['accessToken'] as String?;
        apiClient.currentUserId = (result['user'] as Map<String, dynamic>?)?['id'] as String?;
        ref.read(isLoggedInProvider.notifier).login();
      } else {
        final result = await apiClient.post('/auth/login', {
          'email': emailController.text.trim(),
          'password': passwordController.text,
        });
        apiClient.accessToken = result['accessToken'] as String?;
        apiClient.currentUserId = (result['user'] as Map<String, dynamic>?)?['id'] as String?;
        ref.read(isLoggedInProvider.notifier).login();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.mode == AuthMode.forgot ? 'Đã ghi nhận yêu cầu đặt lại mật khẩu.' : 'Đăng nhập thành công.')),
      );
      if (widget.mode != AuthMode.forgot) context.go('/profile');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }
}
