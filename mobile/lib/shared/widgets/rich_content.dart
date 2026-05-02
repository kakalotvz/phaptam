import 'package:flutter/material.dart';

class RichContent extends StatelessWidget {
  const RichContent({
    required this.content,
    this.baseStyle,
    this.compact = false,
    super.key,
  });

  final String content;
  final TextStyle? baseStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style =
        baseStyle ??
        Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.58);
    final blocks = _normalize(content)
        .split(RegExp(r'\n{2,}'))
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty)
        .toList();

    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          _RichBlock(block: block, baseStyle: style, compact: compact),
          SizedBox(height: compact ? 8 : 14),
        ],
      ],
    );
  }
}

class _RichBlock extends StatelessWidget {
  const _RichBlock({
    required this.block,
    required this.baseStyle,
    required this.compact,
  });

  final String block;
  final TextStyle? baseStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (block.startsWith('## ')) {
      return Text.rich(
        TextSpan(
          children: _inlineSpans(block.substring(3), context),
          style: (compact ? baseStyle : Theme.of(context).textTheme.titleLarge)
              ?.copyWith(height: 1.25, fontWeight: FontWeight.w800),
        ),
        softWrap: true,
      );
    }

    final lines = block.split('\n').map((line) => line.trim()).toList();
    if (lines.every((line) => line.startsWith('- '))) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: EdgeInsets.only(bottom: compact ? 4 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: _inlineSpans(line.substring(2), context),
                        style: baseStyle,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        children: _inlineSpans(lines.join('\n'), context),
        style: baseStyle,
      ),
      softWrap: true,
    );
  }
}

String _normalize(String value) {
  return value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAllMapped(
        RegExp(
          r'<h[1-3][^>]*>(.*?)</h[1-3]>',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '\n\n## ${match.group(1) ?? ''}\n\n',
      )
      .replaceAllMapped(
        RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
        (match) => '\n- ${match.group(1) ?? ''}',
      )
      .replaceAllMapped(
        RegExp(
          r'<(?:strong|b)[^>]*>(.*?)</(?:strong|b)>',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '**${match.group(1) ?? ''}**',
      )
      .replaceAllMapped(
        RegExp(
          r"""<a[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>""",
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '[${match.group(2) ?? ''}](${match.group(1) ?? ''})',
      )
      .replaceAllMapped(
        RegExp(r'<url=(.*?)>(.*?)</url>', caseSensitive: false, dotAll: true),
        (match) => '[${match.group(2) ?? ''}](${match.group(1) ?? ''})',
      )
      .replaceAllMapped(
        RegExp(r'<url>(.*?)</url>', caseSensitive: false, dotAll: true),
        (match) => '[${match.group(1) ?? ''}](${match.group(1) ?? ''})',
      )
      .replaceAllMapped(
        RegExp(r'\[b\](.*?)\[/b\]', caseSensitive: false, dotAll: true),
        (match) => '**${match.group(1) ?? ''}**',
      )
      .replaceAllMapped(
        RegExp(
          r'\[url=(.*?)\](.*?)\[/url\]',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '[${match.group(2) ?? ''}](${match.group(1) ?? ''})',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .trim();
}

List<InlineSpan> _inlineSpans(String value, BuildContext context) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|\[(.+?)\]\((https?:\/\/[^)]+)\)');
  var cursor = 0;

  for (final match in pattern.allMatches(value)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: value.substring(cursor, match.start)));
    }

    final bold = match.group(1);
    final linkText = match.group(2);
    final linkUrl = match.group(3);
    if (bold != null) {
      spans.add(
        TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    } else if (linkText != null && linkUrl != null) {
      spans.add(
        TextSpan(
          text: linkText,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    cursor = match.end;
  }

  if (cursor < value.length) spans.add(TextSpan(text: value.substring(cursor)));
  return spans;
}
