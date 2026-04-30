import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
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
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _submit,
            icon: Icon(isForgot ? Icons.send_outlined : Icons.login),
            label: Text(isForgot ? 'Gửi hướng dẫn' : title),
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

  void _submit() {
    if (widget.mode != AuthMode.forgot) {
      ref.read(isLoggedInProvider.notifier).login();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.mode == AuthMode.forgot
              ? 'Đã ghi nhận yêu cầu đặt lại mật khẩu.'
              : 'Đăng nhập thành công.',
        ),
      ),
    );
    if (widget.mode != AuthMode.forgot) context.go('/profile');
  }
}
