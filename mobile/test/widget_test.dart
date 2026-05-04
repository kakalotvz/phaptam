import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:mobile/app.dart';

void main() {
  testWidgets('renders main app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PhapTamApp()));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('Pháp Tâm'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
