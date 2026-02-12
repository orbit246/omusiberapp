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
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatCompactTR(view.viewCount),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            TextButton(
                              onPressed: () {
                                if (view.onOpen != null) {
                                  view.onOpen!();
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NewsItemPage(view: view),
                                    ),
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    view.readMoreLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 16),
                                ],
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

  String _formatCompactTR(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) {
      double thousands = count / 1000;
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}B';
    }
    double millions = count / 1000000;
    return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final bool isActive;
  final Color? activeColor;

  const _ActionButton({
    required this.icon,
    this.label,
    this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isActive
        ? (activeColor ?? colorScheme.primary)
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
