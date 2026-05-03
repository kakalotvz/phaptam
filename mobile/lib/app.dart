import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/content/content_providers.dart';

class PhapTamApp extends ConsumerStatefulWidget {
  const PhapTamApp({super.key});

  @override
  ConsumerState<PhapTamApp> createState() => _PhapTamAppState();
}

class _PhapTamAppState extends ConsumerState<PhapTamApp>
    with WidgetsBindingObserver {
  var _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshPublicContent(ref));
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(darkModeProvider);
    if (_showSplash) {
      return MaterialApp(
        title: 'Pháp Tâm',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        home: const _PhapTamSplashScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Pháp Tâm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}

class _PhapTamSplashScreen extends StatefulWidget {
  const _PhapTamSplashScreen();

  @override
  State<_PhapTamSplashScreen> createState() => _PhapTamSplashScreenState();
}

class _PhapTamSplashScreenState extends State<_PhapTamSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D1008),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD873).withValues(alpha: 0.28),
                        blurRadius: 72,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/branding/lotus_logo.png',
                    width: 190,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 22),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFF3B0),
                      Color(0xFFFFC857),
                      Color(0xFFC47A22),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'Pháp Tâm',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'serif',
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      shadows: [
                        Shadow(
                          color: Color(0xAA6B2F12),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
