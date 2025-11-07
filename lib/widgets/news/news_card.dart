import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_view.dart';
import 'package:omusiber/pages/news_item_page.dart';
import 'package:omusiber/widgets/news/news_card_item.dart';

/// Presentational card. All data comes from [NewsView].
class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.view});

  final NewsView view;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Image(image: AssetImage(view.heroImage), fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // Flutter >=3.22 has `spacing` on Column. If older, replace with SizedBox.
              spacing: 8,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        view.title,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: view.authorAvatar,
                      child: view.authorAvatar == null
                          ? Icon(
                              Icons.person,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      view.authorName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        view.summary,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Action icons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Favorite toggle (keeps your existing button API)
                        NewsCardItemIconButton(
                          onPressed: () {
                            if (view.onToggleFavorite != null) {
                              view.onToggleFavorite!(!view.isFavorited);
                            }
                          },
                          favoriteIcon: view.isFavorited
                              ? Icons.favorite
                              : Icons.favorite, // filled for both props
                          favoriteBorderIcon: view.isFavorited
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        NewsCardItemIconButton(
                          onPressed: view.onComment,
                          favoriteIcon: Icons.comment,
                          favoriteBorderIcon: Icons.comment_outlined,
                        ),
                        NewsCardItemIconButton(
                          onPressed: view.onShare,
                          favoriteIcon: Icons.share_outlined,
                          favoriteBorderIcon: Icons.share_outlined,
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Metrics
                    Row(
                      children: [
                        Text(
                          '${view.commentCount}${view.commentLabelSuffix}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _formatCompactTR(view.viewCount),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.remove_red_eye,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
                Center(
                  child: GestureDetector(
                    onTap:
                        view.onOpen ??
                        () {
                          // Fallback: navigate to your existing page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NewsItemPage(),
                            ),
                          );
                        },
                    child: Text(
                      view.readMoreLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Turkish-friendly compact number format (e.g., 1_200 -> "1.2 Bin")
  static String _formatCompactTR(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) {
      final v = (n / 1000);
      return '${_trimZero(v)} Bin';
    }
    if (n < 1000000000) {
      final v = (n / 1000000);
      return '${_trimZero(v)} Mn';
    }
    final v = (n / 1000000000);
    return '${_trimZero(v)} Mr';
  }

  static String _trimZero(double v) {
    final s = v.toStringAsFixed(1).replaceAll('.', ','); // 1.2 -> 1,2
    return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
  }
}
