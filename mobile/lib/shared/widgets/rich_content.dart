import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

    if (block.startsWith('### ')) {
      return Text.rich(
        TextSpan(
          children: _inlineSpans(block.substring(4), context),
          style: (compact ? baseStyle : Theme.of(context).textTheme.titleMedium)
              ?.copyWith(height: 1.28, fontWeight: FontWeight.w800),
        ),
        softWrap: true,
      );
    }

    if (block.startsWith('> ')) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.secondaryContainer.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.secondary,
              width: 4,
            ),
          ),
        ),
        child: Text.rich(
          TextSpan(
            children: _inlineSpans(
              block.replaceAll(RegExp(r'^> ', multiLine: true), ''),
              context,
            ),
            style: baseStyle,
          ),
        ),
      );
    }

    final image = RegExp(
      r'^!\[(.*?)\]\((https?:\/\/[^)]+)\)$',
    ).firstMatch(block);
    if (image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          image.group(2)!,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      );
    }

    final video = RegExp(r'^\[\[video:(.*?)\]\]$').firstMatch(block);
    if (video != null) {
      return _VideoLinkCard(url: video.group(1)!);
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

    if (lines.every((line) => RegExp(r'^\d+\. ').hasMatch(line))) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: compact ? 4 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${i + 1}.',
                      style: baseStyle?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: _inlineSpans(
                          lines[i].replaceFirst(RegExp(r'^\d+\. '), ''),
                          context,
                        ),
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
        (match) {
          final tag = match.group(0)?.toLowerCase().startsWith('<h3') == true
              ? '###'
              : '##';
          return '\n\n$tag ${match.group(1) ?? ''}\n\n';
        },
      )
      .replaceAllMapped(
        RegExp(
          r'<blockquote[^>]*>(.*?)</blockquote>',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) =>
            '\n\n> ${(match.group(1) ?? '').replaceAll('\n', '\n> ')}\n\n',
      )
      .replaceAllMapped(
        RegExp(
          r"""<img[^>]*src=["']([^"']+)["'][^>]*>""",
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '\n\n![Hình ảnh](${match.group(1) ?? ''})\n\n',
      )
      .replaceAllMapped(
        RegExp(
          r"""<[^>]*data-video=["']([^"']+)["'][^>]*>.*?</[^>]+>""",
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '\n\n[[video:${match.group(1) ?? ''}]]\n\n',
      )
      .replaceAllMapped(
        RegExp(
          r"""<iframe[^>]*src=["']([^"']+)["'][^>]*>.*?</iframe>""",
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '\n\n[[video:${match.group(1) ?? ''}]]\n\n',
      )
      .replaceAllMapped(
        RegExp(
          r"""<video[^>]*src=["']([^"']+)["'][^>]*>.*?</video>""",
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '\n\n[[video:${match.group(1) ?? ''}]]\n\n',
      )
      .replaceAllMapped(
        RegExp(
          r"""<video[^>]*>.*?<source[^>]*src=["']([^"']+)["'][^>]*>.*?</video>""",
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '\n\n[[video:${match.group(1) ?? ''}]]\n\n',
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
          r'<(?:em|i)[^>]*>(.*?)</(?:em|i)>',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '*${match.group(1) ?? ''}*',
      )
      .replaceAllMapped(
        RegExp(r'<u[^>]*>(.*?)</u>', caseSensitive: false, dotAll: true),
        (match) => '__${match.group(1) ?? ''}__',
      )
      .replaceAllMapped(
        RegExp(r'<sup[^>]*>(.*?)</sup>', caseSensitive: false, dotAll: true),
        (match) => '[sup]${match.group(1) ?? ''}[/sup]',
      )
      .replaceAllMapped(
        RegExp(
          r"""<(?:span|mark)[^>]*style=["']([^"']+)["'][^>]*>(.*?)</(?:span|mark)>""",
          caseSensitive: false,
          dotAll: true,
        ),
        (match) =>
            '[style=${match.group(1) ?? ''}]${match.group(2) ?? ''}[/style]',
      )
      .replaceAllMapped(
        RegExp(
          r'<(?:s|strike)[^>]*>(.*?)</(?:s|strike)>',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '~~${match.group(1) ?? ''}~~',
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
        RegExp(r'\[img\](.*?)\[/img\]', caseSensitive: false, dotAll: true),
        (match) => '\n\n![Hình ảnh](${(match.group(1) ?? '').trim()})\n\n',
      )
      .replaceAllMapped(
        RegExp(r'\[video\](.*?)\[/video\]', caseSensitive: false, dotAll: true),
        (match) => '\n\n[[video:${(match.group(1) ?? '').trim()}]]\n\n',
      )
      .replaceAllMapped(
        RegExp(r'\[quote\](.*?)\[/quote\]', caseSensitive: false, dotAll: true),
        (match) =>
            '\n\n> ${(match.group(1) ?? '').trim().replaceAll('\n', '\n> ')}\n\n',
      )
      .replaceAllMapped(
        RegExp(r'\[b\](.*?)\[/b\]', caseSensitive: false, dotAll: true),
        (match) => '**${match.group(1) ?? ''}**',
      )
      .replaceAllMapped(
        RegExp(r'\[i\](.*?)\[/i\]', caseSensitive: false, dotAll: true),
        (match) => '*${match.group(1) ?? ''}*',
      )
      .replaceAllMapped(
        RegExp(r'\[u\](.*?)\[/u\]', caseSensitive: false, dotAll: true),
        (match) => '__${match.group(1) ?? ''}__',
      )
      .replaceAllMapped(
        RegExp(r'\[s\](.*?)\[/s\]', caseSensitive: false, dotAll: true),
        (match) => '~~${match.group(1) ?? ''}~~',
      )
      .replaceAllMapped(
        RegExp(
          r'\[url=(.*?)\](.*?)\[/url\]',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => '[${match.group(2) ?? ''}](${match.group(1) ?? ''})',
      )
      .replaceAllMapped(
        RegExp(r'\[url\](.*?)\[/url\]', caseSensitive: false, dotAll: true),
        (match) => '[${match.group(1) ?? ''}](${match.group(1) ?? ''})',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .trim();
}

List<InlineSpan> _inlineSpans(String value, BuildContext context) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(
    r'\[style=([^\]]+)\]([\s\S]+?)\[/style\]|\[sup\]([\s\S]+?)\[/sup\]|\*\*(.+?)\*\*|__(.+?)__|~~(.+?)~~|\*(.+?)\*|\[(.+?)\]\((https?:\/\/[^)]+)\)',
  );
  var cursor = 0;

  for (final match in pattern.allMatches(value)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: value.substring(cursor, match.start)));
    }

    final styledCss = match.group(1);
    final styledText = match.group(2);
    final superscript = match.group(3);
    final bold = match.group(4);
    final underline = match.group(5);
    final strike = match.group(6);
    final italic = match.group(7);
    final linkText = match.group(8);
    final linkUrl = match.group(9);
    if (styledCss != null && styledText != null) {
      spans.add(TextSpan(text: styledText, style: _styleFromCss(styledCss)));
    } else if (superscript != null) {
      spans.add(
        TextSpan(
          text: superscript,
          style: const TextStyle(
            fontSize: 11,
            fontFeatures: [FontFeature.superscripts()],
          ),
        ),
      );
    } else if (bold != null) {
      spans.add(
        TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    } else if (underline != null) {
      spans.add(
        TextSpan(
          text: underline,
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
      );
    } else if (strike != null) {
      spans.add(
        TextSpan(
          text: strike,
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
      );
    } else if (italic != null) {
      spans.add(
        TextSpan(
          text: italic,
          style: const TextStyle(fontStyle: FontStyle.italic),
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
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openExternalUrl(linkUrl),
        ),
      );
    }
    cursor = match.end;
  }

  if (cursor < value.length) spans.add(TextSpan(text: value.substring(cursor)));
  return spans;
}

TextStyle _styleFromCss(String css) {
  Color? color;
  Color? backgroundColor;
  double? fontSize;
  String? fontFamily;

  for (final part in css.split(';')) {
    final pieces = part.split(':');
    if (pieces.length < 2) continue;
    final key = pieces.first.trim().toLowerCase();
    final value = pieces.sublist(1).join(':').trim();
    if (key == 'color') color = _cssColor(value);
    if (key == 'background-color') backgroundColor = _cssColor(value);
    if (key == 'font-size') {
      fontSize = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
    }
    if (key == 'font-family') {
      fontFamily = value.split(',').first.replaceAll('"', '').trim();
    }
  }

  return TextStyle(
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontFamily: fontFamily?.isEmpty == true ? null : fontFamily,
  );
}

Color? _cssColor(String value) {
  final trimmed = value.trim();
  final hex = RegExp(
    r'^#([0-9a-f]{3}|[0-9a-f]{6})$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (hex != null) {
    var raw = hex.group(1)!;
    if (raw.length == 3) {
      raw = raw.split('').map((char) => '$char$char').join();
    }
    return Color(int.parse('FF$raw', radix: 16));
  }

  final rgb = RegExp(
    r'rgba?\((\d+),\s*(\d+),\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (rgb == null) return null;
  return Color.fromARGB(
    255,
    int.parse(rgb.group(1)!).clamp(0, 255),
    int.parse(rgb.group(2)!).clamp(0, 255),
    int.parse(rgb.group(3)!).clamp(0, 255),
  );
}

class _VideoLinkCard extends StatelessWidget {
  const _VideoLinkCard({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openExternalUrl(url),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.open_in_new, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternalUrl(String value) async {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
