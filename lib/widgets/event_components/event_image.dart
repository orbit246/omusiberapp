import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';

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
      borderRadius: BorderRadius.circular(12),
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
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (width * pixelRatio).round().clamp(1, 4096).toInt();
    final cacheHeight = (height * pixelRatio).round().clamp(1, 4096).toInt();

    return CachedNetworkImage(
      imageUrl: url.trim(),
      height: height,
      width: width,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      fadeInDuration: const Duration(milliseconds: 220),
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => AppSkeleton(
        width: width,
        height: height,
        borderRadius: BorderRadius.zero,
      ),
      errorWidget: (_, __, ___) => _fallback(cs),
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
