import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app.dart';

void main() {
  testWidgets('renders main app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PhapTamApp()));
    await tester.pumpAndSettle();

    expect(find.text('Pháp Tâm'), findsWidgets);
    expect(find.text('Kinh'), findsOneWidget);
  });
}
