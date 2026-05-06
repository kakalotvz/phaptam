import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

typedef RichContentWordLongPressStart =
    void Function(int wordIndex, String word, Offset globalPosition);
typedef RichContentWordTap =
    void Function(int wordIndex, String word, Offset globalPosition);

class RichContent extends StatefulWidget {
  const RichContent({
    required this.content,
    this.baseStyle,
    this.compact = false,
    this.onWordLongPressStart,
    this.onWordTap,
    this.tapWordIndexes = const {},
    this.wordLongPressDuration = const Duration(milliseconds: 700),
    super.key,
  });

  final String content;
  final TextStyle? baseStyle;
  final bool compact;
  final RichContentWordLongPressStart? onWordLongPressStart;
  final RichContentWordTap? onWordTap;
  final Set<int> tapWordIndexes;
  final Duration wordLongPressDuration;

  @override
  State<RichContent> createState() => _RichContentState();
}

class _RichContentState extends State<RichContent> {
  final _recognizers = <GestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final style =
        widget.baseStyle ??
        Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.58);
    final wordCounter = _WordIndexCounter();
    final blocks = _richContentBlocks(_normalize(widget.content));

    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          _RichBlock(
            block: block,
            baseStyle: style,
            compact: widget.compact,
            wordCounter: wordCounter,
            onWordLongPressStart: widget.onWordLongPressStart,
            onWordTap: widget.onWordTap,
            tapWordIndexes: widget.tapWordIndexes,
            wordLongPressDuration: widget.wordLongPressDuration,
            recognizers: _recognizers,
          ),
          SizedBox(height: widget.compact ? 8 : 14),
        ],
      ],
    );
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}

class _RichBlock extends StatelessWidget {
  const _RichBlock({
    required this.block,
    required this.baseStyle,
    required this.compact,
    required this.wordCounter,
    required this.recognizers,
    required this.tapWordIndexes,
    required this.wordLongPressDuration,
    this.onWordLongPressStart,
    this.onWordTap,
  });

  final String block;
  final TextStyle? baseStyle;
  final bool compact;
  final _WordIndexCounter wordCounter;
  final List<GestureRecognizer> recognizers;
  final Set<int> tapWordIndexes;
  final Duration wordLongPressDuration;
  final RichContentWordLongPressStart? onWordLongPressStart;
  final RichContentWordTap? onWordTap;

  @override
  Widget build(BuildContext context) {
    if (block.startsWith('## ')) {
      return Text.rich(
        TextSpan(
          children: _inlineSpans(
            block.substring(3),
            context,
            wordCounter: wordCounter,
            onWordLongPressStart: onWordLongPressStart,
            onWordTap: onWordTap,
            tapWordIndexes: tapWordIndexes,
            wordLongPressDuration: wordLongPressDuration,
            recognizers: recognizers,
          ),
          style: (compact ? baseStyle : Theme.of(context).textTheme.titleLarge)
              ?.copyWith(height: 1.25, fontWeight: FontWeight.w800),
        ),
        softWrap: true,
      );
    }

    if (block.startsWith('### ')) {
      return Text.rich(
        TextSpan(
          children: _inlineSpans(
            block.substring(4),
            context,
            wordCounter: wordCounter,
            onWordLongPressStart: onWordLongPressStart,
            onWordTap: onWordTap,
            tapWordIndexes: tapWordIndexes,
            wordLongPressDuration: wordLongPressDuration,
            recognizers: recognizers,
          ),
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
              wordCounter: wordCounter,
              onWordLongPressStart: onWordLongPressStart,
              onWordTap: onWordTap,
              tapWordIndexes: tapWordIndexes,
              wordLongPressDuration: wordLongPressDuration,
              recognizers: recognizers,
            ),
            style: baseStyle,
          ),
        ),
      );
    }

    final image = RegExp(
      r'^!\[(.*?)(?:\|(left|center|right))?\]\((https?:\/\/[^)]+)\)$',
    ).firstMatch(block);
    if (image != null) {
      return _AlignedNetworkImage(
        url: image.group(3)!,
        alignment: _readTextAlign(image.group(2)),
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
                        children: _inlineSpans(
                          line.substring(2),
                          context,
                          wordCounter: wordCounter,
                          onWordLongPressStart: onWordLongPressStart,
                          onWordTap: onWordTap,
                          tapWordIndexes: tapWordIndexes,
                          wordLongPressDuration: wordLongPressDuration,
                          recognizers: recognizers,
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
                          wordCounter: wordCounter,
                          onWordLongPressStart: onWordLongPressStart,
                          onWordTap: onWordTap,
                          tapWordIndexes: tapWordIndexes,
                          wordLongPressDuration: wordLongPressDuration,
                          recognizers: recognizers,
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

    final rawText = lines.join('\n');
    final aligned = _looseAlignBlockPattern.firstMatch(rawText);
    final looseAlign = _looseAlignOpenPattern.firstMatch(rawText);
    final alignedText = aligned?.group(2) ?? _stripLooseAlignTags(rawText);
    final alignedTextAlign = _readTextAlign(
      aligned?.group(1) ?? looseAlign?.group(1),
    );

    if (alignedText.startsWith('## ')) {
      return Text.rich(
        TextSpan(
          children: _inlineSpans(
            alignedText.substring(3),
            context,
            wordCounter: wordCounter,
            onWordLongPressStart: onWordLongPressStart,
            onWordTap: onWordTap,
            tapWordIndexes: tapWordIndexes,
            wordLongPressDuration: wordLongPressDuration,
            recognizers: recognizers,
          ),
          style: (compact ? baseStyle : Theme.of(context).textTheme.titleLarge)
              ?.copyWith(height: 1.25, fontWeight: FontWeight.w800),
        ),
        softWrap: true,
        textAlign: alignedTextAlign,
      );
    }

    if (alignedText.startsWith('### ')) {
      return Text.rich(
        TextSpan(
          children: _inlineSpans(
            alignedText.substring(4),
            context,
            wordCounter: wordCounter,
            onWordLongPressStart: onWordLongPressStart,
            onWordTap: onWordTap,
            tapWordIndexes: tapWordIndexes,
            wordLongPressDuration: wordLongPressDuration,
            recognizers: recognizers,
          ),
          style: (compact ? baseStyle : Theme.of(context).textTheme.titleMedium)
              ?.copyWith(height: 1.28, fontWeight: FontWeight.w800),
        ),
        softWrap: true,
        textAlign: alignedTextAlign,
      );
    }

    return Text.rich(
      TextSpan(
        children: _inlineSpans(
          alignedText,
          context,
          wordCounter: wordCounter,
          onWordLongPressStart: onWordLongPressStart,
          onWordTap: onWordTap,
          tapWordIndexes: tapWordIndexes,
          wordLongPressDuration: wordLongPressDuration,
          recognizers: recognizers,
        ),
        style: baseStyle,
      ),
      softWrap: true,
      textAlign: alignedTextAlign,
    );
  }
}

String _normalize(String value) {
  final normalized = _decodeHtmlEntities(value)
      .replaceAll('&amp;nbsp;', ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('\u00A0', ' ')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAllMapped(
        RegExp(
          r'<figure([^>]*)>\s*(<img[^>]*>)\s*</figure>',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) {
          final figureAttrs = match.group(1) ?? '';
          final imageTag = match.group(2) ?? '';
          final url = _htmlAttribute(imageTag, 'src');
          if (url == null) return '';
          final align =
              _htmlTextAlign(figureAttrs) ??
              _htmlAttribute(imageTag, 'data-text-align') ??
              _htmlTextAlign(imageTag);
          return '\n\n${_markdownImage(url, align)}\n\n';
        },
      )
      .replaceAllMapped(
        RegExp(
          r'<(p|div)([^>]*)>(.*?)</\1>',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) {
          final attrs = match.group(2) ?? '';
          final body = match.group(3) ?? '';
          final align = _htmlTextAlign(attrs);
          if (align == null) return '\n\n$body\n\n';
          return '\n\n[align=$align]$body[/align]\n\n';
        },
      )
      .replaceAllMapped(
        RegExp(
          r'<h([1-3])([^>]*)>(.*?)</h[1-3]>',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) {
          final tag = match.group(1) == '3' ? '###' : '##';
          final attrs = match.group(2) ?? '';
          final body = match.group(3) ?? '';
          final align = _htmlTextAlign(attrs);
          final heading = '$tag $body';
          if (align == null) return '\n\n$heading\n\n';
          return '\n\n[align=$align]$heading[/align]\n\n';
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
        (match) {
          final tag = match.group(0) ?? '';
          final align =
              _htmlAttribute(tag, 'data-text-align') ?? _htmlTextAlign(tag);
          return '\n\n${_markdownImage(match.group(1) ?? '', align)}\n\n';
        },
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
        (match) {
          final style = match.group(1) ?? '';
          final body = match.group(2) ?? '';
          final styled = '[style=$style]$body[/style]';
          final align = _htmlTextAlign(style);
          if (align == null) return styled;
          return '[align=$align]$styled[/align]';
        },
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
        RegExp(
          r'\[align\s*=\s*(left|center|right|justify)\s*\]([\s\S]*?)\[/\s*align\s*\]',
          caseSensitive: false,
        ),
        _normalizeAlignedBbCode,
      )
      .replaceAllMapped(
        RegExp(r'\[img\](.*?)\[/img\]', caseSensitive: false, dotAll: true),
        (match) => '\n\n![Hình ảnh](${(match.group(1) ?? '').trim()})\n\n',
      )
      .replaceAllMapped(
        RegExp(
          r'\[img=(left|center|right)\](.*?)\[/img\]',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) =>
            '\n\n${_markdownImage((match.group(2) ?? '').trim(), match.group(1))}\n\n',
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
  return _decodeHtmlEntities(normalized);
}

String _normalizeAlignedBbCode(Match match) {
  final align = (match.group(1) ?? 'left').toLowerCase();
  final body = (match.group(2) ?? '')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
  if (body.isEmpty) return '';

  final bbCodeImage = RegExp(
    r'^\[img(?:=(left|center|right))?\](.*?)\[/img\]$',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(body);
  if (bbCodeImage != null) {
    return '\n\n${_markdownImage((bbCodeImage.group(2) ?? '').trim(), align)}\n\n';
  }

  final markdownImage = RegExp(
    r'^!\[(.*?)(?:\|(left|center|right))?\]\((https?:\/\/[^)]+)\)$',
    caseSensitive: false,
  ).firstMatch(body);
  if (markdownImage != null) {
    return '\n\n${_markdownImage(markdownImage.group(3) ?? '', align)}\n\n';
  }

  return '\n\n[align=$align]$body[/align]\n\n';
}

List<String> _richContentBlocks(String value) {
  final rawBlocks = value
      .split(RegExp(r'\n{2,}'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty);
  final blocks = <String>[];
  String? pendingAlignBlock;

  for (final block in rawBlocks) {
    final pending = pendingAlignBlock;
    if (pending != null) {
      final merged = '$pending\n\n$block';
      if (_looseAlignClosePattern.hasMatch(block)) {
        final aligned = _looseAlignBlockPattern.firstMatch(merged);
        blocks.add(
          aligned == null
              ? _stripLooseAlignTags(merged)
              : '[align=${aligned.group(1)?.toLowerCase() ?? 'left'}]${(aligned.group(2) ?? '').replaceAll(RegExp(r'\n{2,}'), '\n').trim()}[/align]',
        );
        pendingAlignBlock = null;
      } else {
        pendingAlignBlock = merged;
      }
      continue;
    }

    if (_looseAlignOpenPattern.hasMatch(block) &&
        !_looseAlignClosePattern.hasMatch(block)) {
      pendingAlignBlock = block;
      continue;
    }

    final cleaned = _isLooseAlignCloseOnly(block)
        ? ''
        : _stripUnmatchedLooseAlignTags(block);
    if (cleaned.isNotEmpty) blocks.add(cleaned);
  }

  final pending = pendingAlignBlock;
  if (pending != null) {
    final repaired = _repairLooseAlignBlock(pending);
    final cleaned = (repaired ?? _stripLooseAlignTags(pending)).trim();
    if (cleaned.isNotEmpty) blocks.add(cleaned);
  }

  return blocks;
}

String _stripUnmatchedLooseAlignTags(String value) {
  if (_looseAlignBlockPattern.hasMatch(value)) return value;
  return _stripLooseAlignTags(value).trim();
}

String? _repairLooseAlignBlock(String value) {
  final open = _looseAlignOpenPattern.firstMatch(value);
  if (open == null) return null;
  final align = open.group(1)?.toLowerCase() ?? 'left';
  final body = value
      .substring(open.end)
      .replaceAll(_looseAlignClosePattern, '');
  final cleanedBody = body.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
  if (cleanedBody.isEmpty) return null;
  return '[align=$align]$cleanedBody[/align]';
}

String richContentPlainText(String value) {
  return _stripInlineMarkupForWords(_normalize(value))
      .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<InlineSpan> _inlineSpans(
  String value,
  BuildContext context, {
  _WordIndexCounter? wordCounter,
  RichContentWordLongPressStart? onWordLongPressStart,
  RichContentWordTap? onWordTap,
  Set<int> tapWordIndexes = const {},
  Duration wordLongPressDuration = const Duration(milliseconds: 700),
  List<GestureRecognizer>? recognizers,
}) {
  value = _stripLooseAlignTags(value);
  final spans = <InlineSpan>[];
  final pattern = RegExp(
    r'\[style=([^\]]+)\]([\s\S]+?)\[/style\]|\[sup\]([\s\S]+?)\[/sup\]|\*\*([\s\S]+?)\*\*|__([\s\S]+?)__|~~([\s\S]+?)~~|\*([\s\S]+?)\*|\[(.+?)\]\((https?:\/\/[^)]+)\)',
  );
  var cursor = 0;

  for (final match in pattern.allMatches(value)) {
    if (match.start > cursor) {
      spans.addAll(
        _wordAwareSpans(
          value.substring(cursor, match.start),
          wordCounter,
          onWordLongPressStart,
          onWordTap,
          tapWordIndexes,
          wordLongPressDuration,
          recognizers,
        ),
      );
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
      spans.addAll(
        _wordAwareSpans(
          styledText,
          wordCounter,
          onWordLongPressStart,
          onWordTap,
          tapWordIndexes,
          wordLongPressDuration,
          recognizers,
          style: _styleFromCss(styledCss),
        ),
      );
    } else if (superscript != null) {
      spans.addAll(
        _wordAwareSpans(
          superscript,
          wordCounter,
          onWordLongPressStart,
          onWordTap,
          tapWordIndexes,
          wordLongPressDuration,
          recognizers,
          style: const TextStyle(
            fontSize: 11,
            fontFeatures: [FontFeature.superscripts()],
          ),
        ),
      );
    } else if (bold != null) {
      spans.addAll(
        _wordAwareSpans(
          bold,
          wordCounter,
          onWordLongPressStart,
          onWordTap,
          tapWordIndexes,
          wordLongPressDuration,
          recognizers,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    } else if (underline != null) {
      spans.addAll(
        _wordAwareSpans(
          underline,
          wordCounter,
          onWordLongPressStart,
          onWordTap,
          tapWordIndexes,
          wordLongPressDuration,
          recognizers,
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
      );
    } else if (strike != null) {
      spans.addAll(
        _wordAwareSpans(
          strike,
          wordCounter,
          onWordLongPressStart,
          onWordTap,
          tapWordIndexes,
          wordLongPressDuration,
          recognizers,
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
      );
    } else if (italic != null) {
      spans.addAll(
        _wordAwareSpans(
          italic,
          wordCounter,
          onWordLongPressStart,
          onWordTap,
          tapWordIndexes,
          wordLongPressDuration,
          recognizers,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    } else if (linkText != null && linkUrl != null) {
      final linkStyle = TextStyle(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w700,
      );
      if (onWordLongPressStart == null &&
          (onWordTap == null || tapWordIndexes.isEmpty)) {
        spans.add(
          TextSpan(
            text: linkText,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openExternalUrl(linkUrl),
          ),
        );
      } else {
        spans.addAll(
          _wordAwareSpans(
            linkText,
            wordCounter,
            onWordLongPressStart,
            onWordTap,
            tapWordIndexes,
            wordLongPressDuration,
            recognizers,
            style: linkStyle,
          ),
        );
      }
    }
    cursor = match.end;
  }

  if (cursor < value.length) {
    spans.addAll(
      _wordAwareSpans(
        value.substring(cursor),
        wordCounter,
        onWordLongPressStart,
        onWordTap,
        tapWordIndexes,
        wordLongPressDuration,
        recognizers,
      ),
    );
  }
  return spans;
}

List<InlineSpan> _wordAwareSpans(
  String value,
  _WordIndexCounter? wordCounter,
  RichContentWordLongPressStart? onWordLongPressStart,
  RichContentWordTap? onWordTap,
  Set<int> tapWordIndexes,
  Duration wordLongPressDuration,
  List<GestureRecognizer>? recognizers, {
  TextStyle? style,
}) {
  if (wordCounter == null ||
      (onWordLongPressStart == null && onWordTap == null)) {
    return [TextSpan(text: value, style: style)];
  }

  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in _richWordPattern.allMatches(value)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: value.substring(cursor, match.start)));
    }
    final word = match.group(0) ?? '';
    final index = wordCounter.next();
    final GestureRecognizer? recognizer;
    if (onWordTap != null && tapWordIndexes.contains(index)) {
      recognizer = TapGestureRecognizer()
        ..onTapUp = (details) => onWordTap(index, word, details.globalPosition);
    } else if (onWordLongPressStart != null) {
      recognizer = LongPressGestureRecognizer(duration: wordLongPressDuration)
        ..onLongPressStart = (details) =>
            onWordLongPressStart(index, word, details.globalPosition);
    } else {
      recognizer = null;
    }
    if (recognizer != null) recognizers?.add(recognizer);
    spans.add(TextSpan(text: word, style: style, recognizer: recognizer));
    cursor = match.end;
  }
  if (cursor < value.length) spans.add(TextSpan(text: value.substring(cursor)));
  return spans;
}

String _stripInlineMarkupForWords(String value) {
  return value
      .replaceAll(RegExp(r'!\[[^\]]*]\(https?:\/\/[^)]+\)'), ' ')
      .replaceAll(RegExp(r'\[\[video:[^\]]+\]\]'), ' ')
      .replaceAllMapped(
        RegExp(
          r'\[align\s*=\s*(?:left|center|right|justify)\s*\]([\s\S]+?)\[/\s*align\s*\]',
          caseSensitive: false,
        ),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'\[style=[^\]]+\]([\s\S]+?)\[/style\]'),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'\[sup\]([\s\S]+?)\[/sup\]'),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(
          r'\*\*([\s\S]+?)\*\*|__([\s\S]+?)__|~~([\s\S]+?)~~|\*([\s\S]+?)\*',
        ),
        (match) =>
            match.group(1) ??
            match.group(2) ??
            match.group(3) ??
            match.group(4) ??
            '',
      )
      .replaceAllMapped(
        RegExp(r'\[(.+?)\]\((https?:\/\/[^)]+)\)'),
        (match) => match.group(1) ?? '',
      );
}

final RegExp _looseAlignBlockPattern = RegExp(
  r'^\s*\[align\s*=\s*(left|center|right|justify)\s*\]\s*([\s\S]*?)\s*\[/\s*align\s*\]\s*$',
  caseSensitive: false,
);

final RegExp _looseAlignOpenPattern = RegExp(
  r'\[align\s*=\s*(left|center|right|justify)\s*\]',
  caseSensitive: false,
);

final RegExp _looseAlignClosePattern = RegExp(
  r'\[/\s*align\s*\]',
  caseSensitive: false,
);

bool _isLooseAlignCloseOnly(String value) {
  return RegExp(
    r'^\s*\[/\s*align\s*\]\s*$',
    caseSensitive: false,
  ).hasMatch(value);
}

String _stripLooseAlignTags(String value) {
  return value
      .replaceAll(_looseAlignOpenPattern, '')
      .replaceAll(_looseAlignClosePattern, '');
}

String? _htmlAttribute(String tag, String name) {
  final pattern = RegExp(
    "${RegExp.escape(name)}\\s*=\\s*['\"]([^'\"]+)['\"]",
    caseSensitive: false,
  );
  return pattern.firstMatch(tag)?.group(1);
}

String? _htmlTextAlign(String value) {
  final align = RegExp(
    r'text-align\s*:\s*(left|center|right|justify)',
    caseSensitive: false,
  ).firstMatch(value)?.group(1);
  return align?.toLowerCase();
}

String _markdownImage(String url, String? align) {
  final safeAlign = _readTextAlign(align) == TextAlign.left ? null : align;
  final suffix = safeAlign == null ? '' : '|${safeAlign.toLowerCase()}';
  return '![Hình ảnh$suffix]($url)';
}

TextAlign _readTextAlign(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    case 'justify':
      return TextAlign.justify;
    case 'left':
    default:
      return TextAlign.left;
  }
}

Alignment _readImageAlignment(TextAlign align) {
  switch (align) {
    case TextAlign.center:
      return Alignment.center;
    case TextAlign.right:
      return Alignment.centerRight;
    case TextAlign.left:
    case TextAlign.justify:
    case TextAlign.start:
    case TextAlign.end:
      return Alignment.centerLeft;
  }
}

String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&amp;nbsp;', ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&ensp;', ' ')
      .replaceAll('&emsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lsqb;', '[')
      .replaceAll('&lbrack;', '[')
      .replaceAll('&rsqb;', ']')
      .replaceAll('&rbrack;', ']')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final code = int.tryParse(match.group(1) ?? '');
        if (code == null) return match.group(0) ?? '';
        return String.fromCharCode(code);
      })
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
        final code = int.tryParse(match.group(1) ?? '', radix: 16);
        if (code == null) return match.group(0) ?? '';
        return String.fromCharCode(code);
      });
}

class _WordIndexCounter {
  var value = 0;

  int next() => value++;
}

final RegExp _richWordPattern = RegExp(
  r"[0-9A-Za-zÀ-ỹ]+(?:[-'][0-9A-Za-zÀ-ỹ]+)?",
  unicode: true,
);

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

class _AlignedNetworkImage extends StatelessWidget {
  const _AlignedNetworkImage({required this.url, required this.alignment});

  final String url;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth > 420
            ? 420.0
            : constraints.maxWidth;
        return Align(
          alignment: _readImageAlignment(alignment),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              url,
              width: imageWidth,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
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
