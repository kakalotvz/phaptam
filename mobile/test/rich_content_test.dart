import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/rich_content.dart';

void main() {
  testWidgets('keeps image and inline formats inside align blocks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RichContent(
            content:
                '[align=center]![Hình ảnh](https://example.com/image.webp)[/align]\n\n'
                '[align=center][style=display: block; text-align: center]***Chữ đậm nghiêng***[/style][/align]\n\n'
                '[align=left][align=right]**Chữ đậm** và *chữ nghiêng* và __gạch chân__[/align][/align]',
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);

    final renderedText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');

    expect(renderedText, contains('Chữ đậm nghiêng'));
    expect(renderedText, contains('Chữ đậm'));
    expect(renderedText, contains('chữ nghiêng'));
    expect(renderedText, isNot(contains('![')));
    expect(renderedText, isNot(contains('[align=')));
    expect(renderedText, isNot(contains('*')));

    final spans = tester
        .widgetList<RichText>(find.byType(RichText))
        .expand((widget) => _flattenTextSpans(widget.text))
        .toList();
    expect(
      spans
          .where((span) => span.text?.contains('Chữ đậm nghiêng') ?? false)
          .single
          .style
          ?.fontWeight,
      isNotNull,
    );
    expect(
      spans
          .where((span) => span.text?.contains('Chữ đậm nghiêng') ?? false)
          .single
          .style
          ?.fontStyle,
      FontStyle.italic,
    );
    expect(
      spans
          .where((span) => span.text?.contains('gạch chân') ?? false)
          .single
          .style
          ?.decoration,
      TextDecoration.underline,
    );
  });

  testWidgets('keeps intentional blank paragraphs from admin content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RichContent(
            content: '<p>Đoạn một</p><p><br></p><p>Đoạn hai</p>',
          ),
        ),
      ),
    );

    final renderedText = _renderedText(tester);
    expect(renderedText, contains('Đoạn một'));
    expect(renderedText, contains('Đoạn hai'));
    expect(renderedText, isNot(contains('<br>')));
  });

  testWidgets('keeps admin images inside aligned html paragraphs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RichContent(
            content:
                '<p style="text-align: left;"><span style="display: block; text-align: center;"><img src="https://example.com/image.webp" alt="Hình ảnh"></span></p>',
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final renderedText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(renderedText, isNot(contains('![')));
    expect(renderedText, isNot(contains('[[blank-line]]')));
  });

  testWidgets('keeps blank lines created with double br tags', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RichContent(content: '<p>Đoạn một<br><br>Đoạn hai</p>'),
        ),
      ),
    );

    final renderedText = _renderedText(tester);
    expect(renderedText, contains('Đoạn một'));
    expect(renderedText, contains('Đoạn hai'));
    expect(renderedText, isNot(contains('<br>')));
  });
}

List<TextSpan> _flattenTextSpans(InlineSpan span) {
  final spans = <TextSpan>[];
  if (span is TextSpan) {
    if (span.text != null) spans.add(span);
    for (final child in span.children ?? const <InlineSpan>[]) {
      spans.addAll(_flattenTextSpans(child));
    }
  }
  return spans;
}

String _renderedText(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText())
      .join('\n');
}
