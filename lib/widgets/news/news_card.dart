import 'package:flutter/material.dart';
import 'package:omusiber/widgets/news/news_card_item.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.asset('assets/news.webp', fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ("Haber Başlığı uzun olabilir ve burada gösterilecektir"),
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    CircleAvatar(radius: 12, backgroundImage: AssetImage('assets/news.webp')),
                    SizedBox(width: 8),
                    Text(
                      "Yazar Adı",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut  nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NewsCardItemIconButton(
                          onPressed: () {},
                          favoriteIcon: Icons.favorite,
                          favoriteBorderIcon: Icons.favorite_border,
                        ),
                        NewsCardItemIconButton(
                          onPressed: () {},
                          favoriteIcon: Icons.comment,
                          favoriteBorderIcon: Icons.comment_outlined,
                        ),
                        NewsCardItemIconButton(
                          onPressed: () {},
                          favoriteIcon: Icons.share_outlined,
                          favoriteBorderIcon: Icons.share_outlined,
                        ),
                      ],
                    ),
                    Spacer(),
                    Row(
                      children: [
                        Text(
                          "0 Yorum",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                        ),
                        SizedBox(width: 16),
                        Text(
                          "1.2 Bin",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.remove_red_eye, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
                Center(
                  child: Text(
                    "Devamını Oku",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
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
}
