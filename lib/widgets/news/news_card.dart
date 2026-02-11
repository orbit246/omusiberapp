import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:omusiber/pages/news_item_page.dart';

/// Presentational card. All data comes from [NewsView].
class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.view});

  final NewsView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              SizedBox(
                height: 220,
                width: double.infinity,
                child: view.heroImage != null
                    ? Image.network(
                        view.heroImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                      )
                    : Container(color: colorScheme.surfaceContainerHighest),
              ),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      view.title,
                      style: theme.textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Author Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: view.authorAvatar,
                          backgroundColor: colorScheme.primaryContainer,
                          child: view.authorAvatar == null
                              ? Icon(
                                  Icons.person,
                                  size: 14,
                                  color: colorScheme.onPrimaryContainer,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          view.authorName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (view.publishedAtText != null)
                          Text(
                            view.publishedAtText!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 16),

                    // Summary
                    Text(
                      view.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.8),
                        height: 1.6,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 20),

                    // Actions & Metrics
                    Row(
                      children: [
                        // Left: Actions
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionButton(
                              icon: view.isFavorited
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              label: view.likeCount > 0
                                  ? _formatCompactTR(view.likeCount)
                                  : null,
                              isActive: view.isFavorited,
                              activeColor: Colors.redAccent,
                              onTap: () {
                                final nextValue = !view.isFavorited;
                                if (view.onToggleFavorite != null) {
                                  view.onToggleFavorite!(nextValue);
                                } else {
                                  unawaited(
                                    NewsFetcher().trackNewsLike(
                                      view.id,
                                      isLiked: nextValue,
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 16),
                            _ActionButton(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: view.commentCount > 0
                                  ? '${view.commentCount}'
                                  : null,
                              onTap: view.onComment,
                            ),
                            const SizedBox(width: 16),
                            _ActionButton(
                              icon: Icons.share_outlined,
                              onTap: view.onShare,
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Right: View Count & Read More
                        Row(
                          children: [
                            Icon(
                              Icons.remove_red_eye_outlined,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatCompactTR(view.viewCount),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            InkWell(
                              onTap:
                                  view.onOpen ??
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            NewsItemPage(view: view),
                                      ),
                                    );
                                  },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  view.readMoreLabel,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCompactTR(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) {
      final v = (n / 1000);
      return '${_trimZero(v)} Bin';
    }
    if (n < 1000000000) {
      final v = (n / 1000000);
      return '${_trimZero(v)} M';
    }
    final v = (n / 1000000000);
    return '${_trimZero(v)} Mr';
  }

  static String _trimZero(double v) {
    final s = v.toStringAsFixed(1).replaceAll('.', ',');
    return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.label,
    this.isActive = false,
    this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? (activeColor ?? theme.colorScheme.primary)
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
