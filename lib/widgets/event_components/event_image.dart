import 'package:flutter/material.dart';

class EventImageBlock extends StatelessWidget {
  const EventImageBlock({
    super.key,
    required this.imageUrl,
    this.height = 110,
    this.width = 100,
  });

  final String imageUrl;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _NetworkThumb(url: imageUrl, height: height, width: width),
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  const _NetworkThumb({
    required this.url,
    required this.height,
    required this.width,
  });
  final String url;
  final double height;
  final double width;

  bool get _validUrl => url.trim().startsWith('http');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_validUrl) return _fallback(cs);
    return Image.network(
      url.trim(),
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback(cs),
    );
  }

  Widget _fallback(ColorScheme cs) {
    return Container(
      height: height,
      width: width,
      color: cs.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}
