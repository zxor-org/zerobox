import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/widgets/horizontal_scroller.dart';
import 'package:zerobox/src/app/widgets/network_img_layer.dart';

/// Renders the safe, presentation-only subset of XenForo HTML as Flutter
/// widgets.
///
/// Rendering rules:
/// - Dropped entirely: script/style/iframe/form/input/button.
/// - Only http/https URIs are allowed; placeholder images are filtered.
/// - Tables render as rows of equally-wide cells.
/// - Pure-media blocks render as a horizontal image gallery.
/// - Block elements nested inside inline containers split the container
///   into a block flow.
/// - XenForo unfurl blocks render as link cards.
class CommunityHtmlContent extends StatelessWidget {
  const CommunityHtmlContent({super.key, required this.html, this.baseUri});

  final String html;
  final Uri? baseUri;

  static final _plainUrlPattern = RegExp(
    r'(https?:\/\/[^\s<>"\u3000]+|www\.[^\s<>"\u3000]+)',
    caseSensitive: false,
  );

  static const _droppedTags = {
    'script',
    'style',
    'iframe',
    'form',
    'input',
    'button',
  };

  static const _blockTags = {
    'p',
    'div',
    'table',
    'thead',
    'tbody',
    'tfoot',
    'tr',
    'td',
    'th',
    'blockquote',
    'pre',
    'ul',
    'ol',
    'li',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'figure',
    'article',
    'section',
    'hr',
    'dl',
    'dt',
    'dd',
    'video',
    'audio',
  };

  static const _containerTags = {
    'figure',
    'div',
    'article',
    'section',
    'thead',
    'tbody',
    'tfoot',
    'tr',
    'td',
    'th',
  };

  @override
  Widget build(BuildContext context) {
    final document = html_parser.parseFragment(html);
    return _flowColumn(context, document.nodes);
  }

  Widget _flowColumn(BuildContext context, List<dom.Node> nodes) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: _renderFlow(context, nodes),
  );

  /// Renders a mixed node list: consecutive inline nodes are grouped into a
  /// single paragraph, standalone media (a bare image, or a link wrapping
  /// only an image) collects into a gallery, and block nodes render as
  /// standalone widgets.
  List<Widget> _renderFlow(BuildContext context, List<dom.Node> nodes) {
    final widgets = <Widget>[];
    var inlineBuffer = <dom.Node>[];
    var mediaBuffer = <dom.Element>[];

    bool isLineBreak(dom.Node node) =>
        node is dom.Element && node.localName == 'br';

    void flushInline() {
      final buffer = inlineBuffer;
      inlineBuffer = <dom.Node>[];
      final renderable = buffer
          .where(
            (node) =>
                (node is dom.Element && node.localName == 'br') ||
                _hasRenderableContent(node),
          )
          .toList();
      while (renderable.isNotEmpty && isLineBreak(renderable.first)) {
        renderable.removeAt(0);
      }
      while (renderable.isNotEmpty && isLineBreak(renderable.last)) {
        renderable.removeLast();
      }
      if (renderable.isNotEmpty) {
        widgets.add(_paragraph(context, renderable));
      }
    }

    void flushMedia() {
      final buffer = mediaBuffer;
      mediaBuffer = <dom.Element>[];
      if (buffer.isNotEmpty) {
        widgets.add(_mediaGallery(context, buffer));
      }
    }

    bool inlineEndsWithBreak() {
      final last = inlineBuffer.lastOrNull;
      return last is dom.Element && last.localName == 'br';
    }

    for (final node in nodes) {
      if (node is dom.Text) {
        if (node.text.trim().isEmpty) continue;
        flushMedia();
        inlineBuffer.add(node);
        continue;
      }
      if (node is! dom.Element) continue;
      final mediaImage = _standaloneMediaImage(node);
      if (mediaImage != null) {
        // Images embedded in a sentence stay inline (emotes); images that
        // are not explicitly marked as emotes become gallery items even when
        // the source HTML places them directly after text.
        if (inlineBuffer.isEmpty ||
            inlineEndsWithBreak() ||
            !_isInlineEmote(mediaImage)) {
          flushInline();
          mediaBuffer.add(node);
        } else {
          flushMedia();
          inlineBuffer.add(node);
        }
        continue;
      }
      if (_isInlineNode(node)) {
        if (node.localName != 'br') flushMedia();
        inlineBuffer.add(node);
        continue;
      }
      flushInline();
      flushMedia();
      final widget = _renderBlock(context, node);
      if (widget != null) widgets.add(widget);
    }
    flushInline();
    flushMedia();
    return widgets;
  }

  /// Returns the image element when [node] is a standalone media node: a
  /// bare image, or a link without visible text wrapping a single image.
  dom.Element? _standaloneMediaImage(dom.Element node) {
    if (node.localName == 'img') {
      return _imageUri(node) == null ? null : node;
    }
    if (node.localName == 'a' && _visibleText(node).isEmpty) {
      return node.children
          .where(
            (child) => child.localName == 'img' && _imageUri(child) != null,
          )
          .firstOrNull;
    }
    return null;
  }

  bool _isInlineEmote(dom.Element image) {
    final classes = image.classes.map((value) => value.toLowerCase()).toSet();
    return image.attributes.containsKey('data-smilie') ||
        image.attributes.containsKey('data-emoticon') ||
        classes.any(
          (value) =>
              value.contains('smilie') ||
              value.contains('smiley') ||
              value.contains('emote') ||
              value.contains('emoji'),
        );
  }

  bool _isInlineNode(dom.Element element) {
    if (_droppedTags.contains(element.localName)) return false;
    if (_isUnfurl(element)) return false;
    if (_blockTags.contains(element.localName)) return false;
    return !_containsBlockChild(element);
  }

  bool _containsBlockChild(dom.Element element) {
    for (final child in element.nodes) {
      if (child is! dom.Element) continue;
      if (_isUnfurl(child) || _blockTags.contains(child.localName)) return true;
      if (_containsBlockChild(child)) return true;
    }
    return false;
  }

  Widget? _renderBlock(BuildContext context, dom.Element element) {
    if (_droppedTags.contains(element.localName)) return null;
    if (_isUnfurl(element)) return _unfurl(context, element);
    switch (element.localName) {
      case 'img':
        return _imageBox(context, element);
      case 'a':
        return _anchorBlock(context, element);
      case 'hr':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Divider(),
        );
      case 'blockquote':
        if (!_hasRenderableContent(element)) return null;
        return Container(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
          ),
          child: _flowColumn(context, element.nodes),
        );
      case 'pre':
        if (_visibleText(element).isEmpty) return null;
        return Container(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: SelectableText(element.text),
        );
      case 'ul':
      case 'ol':
        return _list(context, element);
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        if (_isMediaOnly(element)) return _mediaGallery(context, element.nodes);
        final text = _visibleText(element);
        if (text.isEmpty) return null;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        );
      case 'table':
        return _table(context, element);
      case 'p':
        if (_isMediaOnly(element)) return _mediaGallery(context, element.nodes);
        if (!_hasRenderableContent(element)) return null;
        return _flowColumn(context, element.nodes);
      default:
        if (_containerTags.contains(element.localName)) {
          return _flowColumn(context, element.nodes);
        }
        if (!_hasRenderableContent(element)) return null;
        return _flowColumn(context, element.nodes);
    }
  }

  Widget _anchorBlock(BuildContext context, dom.Element element) {
    final uri = _safeUri(element.attributes['href']);
    final image = element.children
        .where((child) => child.localName == 'img')
        .cast<dom.Element?>()
        .firstOrNull;
    if (uri != null && image != null && _visibleText(element).isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _launch(uri),
        child: _imageBox(context, image),
      );
    }
    if (!_hasRenderableContent(element)) return const SizedBox.shrink();
    return _paragraph(context, [element]);
  }

  bool _isMediaOnly(dom.Element element) {
    if (_visibleText(element).isNotEmpty) return false;
    return _isMediaOnlyNodes(element.nodes);
  }

  bool _isMediaOnlyNodes(List<dom.Node> nodes) {
    final meaningful = nodes.where((node) {
      if (node is dom.Text) return _cleanText(node.text).trim().isNotEmpty;
      if (node is dom.Element) return node.localName != 'br';
      return false;
    });
    if (meaningful.isEmpty) return false;
    return meaningful.every((node) {
      if (node is! dom.Element) return false;
      if (node.localName == 'img') return _imageUri(node) != null;
      if (node.localName == 'a') {
        return _visibleText(node).isEmpty &&
            node.children.any(
              (child) => child.localName == 'img' && _imageUri(child) != null,
            );
      }
      return false;
    });
  }

  bool _hasRenderableContent(dom.Node node) {
    if (node is dom.Text) return _cleanText(node.text).trim().isNotEmpty;
    if (node is! dom.Element) return false;
    if (node.localName == 'br') return false;
    if (_droppedTags.contains(node.localName)) return false;
    if (node.localName == 'img') return _imageUri(node) != null;
    return _visibleText(node).isNotEmpty ||
        node.children.any(_hasRenderableContent);
  }

  Widget _list(BuildContext context, dom.Element element) {
    final items = element.children
        .where((child) => child.localName == 'li')
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(element.localName == 'ol' ? '${index + 1}.' : '•'),
              ),
              Expanded(child: _flowColumn(context, items[index].nodes)),
            ],
          ),
      ],
    );
  }

  Widget _table(BuildContext context, dom.Element element) {
    final rows = <dom.Element>[];
    void collect(dom.Node node) {
      if (node is! dom.Element) return;
      if (node.localName == 'tr') {
        rows.add(node);
        return;
      }
      for (final child in node.nodes) {
        collect(child);
      }
    }

    for (final node in element.nodes) {
      collect(node);
    }
    if (rows.isEmpty) return _flowColumn(context, element.nodes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final cell in row.children.where(
                  (child) => child.localName == 'td' || child.localName == 'th',
                )) ...[
                  if (cell != row.children.first) const SizedBox(width: 8),
                  Expanded(child: _flowColumn(context, cell.nodes)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _paragraph(BuildContext context, List<dom.Node> nodes) => Padding(
    padding: EdgeInsets.zero,
    child: Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: DefaultTextStyle.of(context).style.color,
        ),
        children: _inline(context, nodes),
      ),
    ),
  );

  Widget _mediaGallery(BuildContext context, List<dom.Node> nodes) {
    final media = _mediaElements(nodes);
    if (media.isEmpty) return const SizedBox.shrink();
    if (media.length == 1) return _imageBox(context, media.single);
    return HorizontalScroller(
      height: 240,
      children: [
        for (final image in media)
          _imageBox(context, image, compactHeight: 240),
      ],
    );
  }

  List<dom.Element> _mediaElements(List<dom.Node> nodes) {
    final media = <dom.Element>[];
    for (final node in nodes) {
      if (node is! dom.Element) continue;
      if (node.localName == 'img' && _imageUri(node) != null) {
        media.add(node);
        continue;
      }
      if (node.localName == 'a' && _visibleText(node).isEmpty) {
        final image = node.children
            .where(
              (child) => child.localName == 'img' && _imageUri(child) != null,
            )
            .firstOrNull;
        if (image != null) media.add(image);
      }
    }
    return media;
  }

  Widget _imageBox(
    BuildContext context,
    dom.Element element, {
    double? compactHeight,
  }) {
    final uri = _imageUri(element);
    if (uri == null) return const SizedBox.shrink();
    final width = _dimension(element.attributes['width']);
    final height = _dimension(element.attributes['height']);
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasSize = width != null && height != null && height > 0;
        final aspect = hasSize ? width / height : 1.0;
        var maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite) maxWidth = 640;
        late double displayWidth;
        late double displayHeight;
        if (compactHeight != null && !hasSize) {
          return Align(
            alignment: Alignment.centerLeft,
            child: NetworkImgAutoWidth(
              src: uri.toString(),
              height: compactHeight,
              maxWidth: 360,
            ),
          );
        }
        if (compactHeight != null) {
          displayHeight = compactHeight;
          displayWidth = (displayHeight * aspect).clamp(1.0, 360.0);
        } else {
          displayWidth = hasSize ? width : maxWidth;
          displayWidth = displayWidth.clamp(1.0, maxWidth).toDouble();
          displayHeight = displayWidth / aspect;
          if (displayHeight < 240) {
            displayHeight = 240;
            displayWidth = (displayHeight * aspect)
                .clamp(1.0, maxWidth)
                .toDouble();
          }
          if (displayHeight > 480) {
            displayHeight = 480;
            displayWidth = (displayHeight * aspect)
                .clamp(1.0, maxWidth)
                .toDouble();
          }
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: NetworkImgLayer(
                src: uri.toString(),
                width: displayWidth,
                height: displayHeight,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isUnfurl(dom.Element element) {
    final classes = element.classes;
    return element.attributes['data-unfurl'] == 'true' ||
        classes.contains('js-unfurl') ||
        classes.contains('bbCodeBlock--unfurl');
  }

  Widget _unfurl(BuildContext context, dom.Element element) {
    final link = element.querySelector('a[href]');
    final uri = _safeUri(
      link?.attributes['href'] ?? element.attributes['data-url'],
    );
    final title = _visibleText(
      element.querySelector('.js-unfurl-title') ?? link ?? element,
    );
    final snippet = _visibleText(element.querySelector('.js-unfurl-desc'));
    final host = element.attributes['data-host'] ?? uri?.host ?? '';
    final image = element.querySelector('.bbCodeBlockUnfurl-image, img');
    final imageUri = image == null ? null : _imageUri(image);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: uri == null ? null : () => _launch(uri),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUri != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: NetworkImgLayer(
                      src: imageUri.toString(),
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      if (snippet.isNotEmpty)
                        Text(
                          snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (host.isNotEmpty)
                        Text(
                          host,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _inline(
    BuildContext context,
    List<dom.Node> nodes, {
    TextStyle? style,
  }) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.data.replaceAll(RegExp(r'[ \t\r\n]+'), ' ');
        if (text.trim().isNotEmpty) {
          spans.addAll(_linkifiedText(context, text, style));
        }
        continue;
      }
      if (node is! dom.Element) continue;
      if (node.localName == 'br') {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      if (node.localName == 'img') {
        final uri = _imageUri(node);
        if (uri != null) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: NetworkImgLayer(
                  src: uri.toString(),
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }
        continue;
      }
      var nextStyle = style;
      if (node.localName == 'strong' || node.localName == 'b') {
        nextStyle = (style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w700,
        );
      }
      if (node.localName == 'em' || node.localName == 'i') {
        nextStyle = (nextStyle ?? const TextStyle()).copyWith(
          fontStyle: FontStyle.italic,
        );
      }
      if (node.localName == 's' || node.localName == 'del') {
        nextStyle = (nextStyle ?? const TextStyle()).copyWith(
          decoration: TextDecoration.lineThrough,
        );
      }
      if (node.localName == 'code') {
        nextStyle = (nextStyle ?? const TextStyle()).copyWith(
          fontFamily: 'monospace',
        );
      }
      final children = _inline(context, node.nodes, style: nextStyle);
      if (node.localName == 'a') {
        final uri = _safeUri(node.attributes['href']);
        final linkStyle = _linkStyle(context, nextStyle);
        spans.add(
          TextSpan(
            children: children,
            style: linkStyle,
            recognizer: uri == null
                ? null
                : (TapGestureRecognizer()..onTap = () => _launch(uri)),
          ),
        );
      } else {
        spans.add(TextSpan(children: children, style: nextStyle));
      }
    }
    return spans;
  }

  List<InlineSpan> _linkifiedText(
    BuildContext context,
    String text,
    TextStyle? style,
  ) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _plainUrlPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: style),
        );
      }
      final rawMatch = match.group(0)!;
      final split = _splitTrailingPunctuation(rawMatch);
      final linkText = split.$1;
      final trailing = split.$2;
      final uri = _safeUri(
        linkText.startsWith('www.') ? 'https://$linkText' : linkText,
      );
      if (uri == null) {
        spans.add(TextSpan(text: rawMatch, style: style));
      } else {
        spans.add(
          TextSpan(
            text: linkText,
            style: _linkStyle(context, style),
            recognizer: TapGestureRecognizer()..onTap = () => _launch(uri),
          ),
        );
        if (trailing.isNotEmpty) {
          spans.add(TextSpan(text: trailing, style: style));
        }
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }
    return spans;
  }

  (String, String) _splitTrailingPunctuation(String raw) {
    var end = raw.length;
    while (end > 0 && '.,;:!?，。；：！？)）]】'.contains(raw[end - 1])) {
      end--;
    }
    return (raw.substring(0, end), raw.substring(end));
  }

  TextStyle _linkStyle(BuildContext context, TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: Theme.of(context).colorScheme.primary,
      );

  Uri? _safeUri(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('#')) return null;
    final normalized = trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
    final uri = baseUri?.resolve(normalized) ?? Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    return uri;
  }

  Uri? _imageUri(dom.Element element) {
    const attrs = [
      'src',
      'data-src',
      'data-url',
      'data-lazy-src',
      'data-original',
      'data-full',
    ];
    for (final attr in attrs) {
      final uri = _safeUri(element.attributes[attr]);
      if (_isUsableImageUri(uri)) return uri;
    }
    final srcset =
        element.attributes['srcset'] ?? element.attributes['data-srcset'];
    final uri = _safeUri(_firstSrcSetUrl(srcset));
    return _isUsableImageUri(uri) ? uri : null;
  }

  bool _isUsableImageUri(Uri? uri) {
    if (uri == null) return false;
    final text = uri.toString().toLowerCase();
    return !text.endsWith('/clear.png') &&
        !text.endsWith('/blank.gif') &&
        !text.contains('spacer') &&
        !text.contains('transparent');
  }

  String? _firstSrcSetUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final first = raw.split(',').first.trim();
    if (first.isEmpty) return null;
    return first.split(RegExp(r'\s+')).first.trim();
  }

  void _launch(Uri uri) {
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _visibleText(dom.Element? element) =>
      element == null ? '' : _cleanText(element.text).trim();

  String _cleanText(String text) =>
      text.replaceAll('\u200b', '').replaceAll('\u00a0', ' ');

  double? _dimension(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return double.tryParse(raw.trim().replaceAll(RegExp(r'[^0-9.]'), ''));
  }
}
