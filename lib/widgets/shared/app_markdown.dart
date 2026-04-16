import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class AppMarkdownBody extends StatelessWidget {
  const AppMarkdownBody({
    super.key,
    required this.data,
    this.selectable = false,
  });

  final String data;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MarkdownBody(
      data: data,
      selectable: selectable,
      styleSheet: _markdownStyleSheet(theme),
      onTapLink: (text, href, title) => _openMarkdownLink(context, href),
    );
  }
}

class AppMarkdownPreview extends StatelessWidget {
  const AppMarkdownPreview({
    super.key,
    required this.data,
    required this.maxHeight,
    required this.backgroundColor,
  });

  final String data;
  final double maxHeight;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: maxHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: constraints.maxWidth,
                  maxWidth: constraints.maxWidth,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: MarkdownBody(
                    data: data,
                    styleSheet: _markdownStyleSheet(theme),
                    onTapLink: (text, href, title) =>
                        _openMarkdownLink(context, href),
                  ),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        backgroundColor.withValues(alpha: 0),
                        backgroundColor,
                      ],
                      stops: const [0.72, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

MarkdownStyleSheet _markdownStyleSheet(ThemeData theme) {
  final cs = theme.colorScheme;
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.82),
      height: 1.5,
    ),
    h1: theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
    ),
    h2: theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
    ),
    h3: theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    ),
    listBullet: theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.82),
    ),
    strong: theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    ),
    em: theme.textTheme.bodyMedium?.copyWith(
      fontStyle: FontStyle.italic,
      color: cs.onSurface.withValues(alpha: 0.82),
    ),
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontStyle: FontStyle.italic,
      height: 1.5,
    ),
    a: theme.textTheme.bodyMedium?.copyWith(
      color: cs.primary,
      decoration: TextDecoration.underline,
      decorationColor: cs.primary,
    ),
    code: theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurface,
      backgroundColor: cs.surfaceContainerHighest,
    ),
  );
}

Future<void> _openMarkdownLink(BuildContext context, String? href) async {
  if (href == null || href.isEmpty) return;

  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(href);
  if (uri == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Baglanti acilamadi.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened || !context.mounted) return;

  messenger.showSnackBar(
    SnackBar(
      content: Text('Baglanti acilamadi: $href'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
