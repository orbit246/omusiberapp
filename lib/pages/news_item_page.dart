import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_view.dart';
import 'package:omusiber/widgets/home/simple_appbar.dart';
import 'package:omusiber/widgets/shared/square_action.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsItemPage extends StatefulWidget {
  const NewsItemPage({super.key, required this.view});

  final NewsView view;

  @override
  State<NewsItemPage> createState() => _NewsItemPageState();
}

class _NewsItemPageState extends State<NewsItemPage> {
  final CarouselSliderController buttonCarouselController =
      CarouselSliderController();
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;

    // Decide what to show in the carousel:
    // If view.imageUrls is empty, just show the heroImage or fallback asset.
    final List<String> images = view.imageUrls.isNotEmpty
        ? view.imageUrls
        : (view.heroImage != null ? [view.heroImage!] : <String>[]);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: SimpleAppbar(title: "Haber Detayları"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: ListView(
                  children: [
                    Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(
                        height: 250,
                        child: images.isEmpty
                            ? Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                child: Center(
                                  child: Text(
                                    'Görsel bulunamadı',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              )
                            : CarouselSlider(
                                carouselController: buttonCarouselController,
                                options: CarouselOptions(
                                  height: 250,
                                  viewportFraction: 1,
                                  enableInfiniteScroll: true,
                                  autoPlay: true,
                                  onPageChanged: (index, reason) {
                                    setState(() {
                                      _current = index;
                                    });
                                  },
                                ),
                                items: images.map((imagePath) {
                                  return Stack(
                                    children: [
                                      // Decide asset vs network:
                                      Positioned.fill(
                                        child: imagePath.startsWith('http')
                                            ? Image.network(
                                                imagePath,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      // Fallback if this specific
                                                      // image fails.
                                                      return Image.asset(
                                                        'assets/news.webp',
                                                        fit: BoxFit.cover,
                                                      );
                                                    },
                                              )
                                            : Image.asset(
                                                imagePath,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                      Positioned(
                                        bottom: 10,
                                        right: 10,
                                        left: 10,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: images
                                              .asMap()
                                              .entries
                                              .map<Widget>((entry) {
                                                return GestureDetector(
                                                  onTap: () {
                                                    buttonCarouselController
                                                        .animateToPage(
                                                          entry.key,
                                                        );
                                                    setState(() {
                                                      _current = entry.key;
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 8.0,
                                                    height: 8.0,
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8.0,
                                                          horizontal: 4.0,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color:
                                                          (Theme.of(
                                                                        context,
                                                                      ).brightness ==
                                                                      Brightness
                                                                          .dark
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .black)
                                                              .withOpacity(
                                                                _current ==
                                                                        entry
                                                                            .key
                                                                    ? 0.9
                                                                    : 0.4,
                                                              ),
                                                    ),
                                                  ),
                                                );
                                              })
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),

                    // Title
                    Text(
                      view.title,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    // Meta: author + date
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: view.authorAvatar,
                          child: view.authorAvatar == null
                              ? Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          view.authorName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        if (view.publishedAtText != null)
                          Text(
                            view.publishedAtText!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Optional tags
                    if (view.tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: view.tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 12),

                    // Full description / body
                    Text(
                      view.fullText ?? view.summary,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Pinned bottom actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // "Haberlere Geri Dön" action – you can wire this to view.onOpen or another callback
                        launchUrl(Uri.parse(view.detailUrl!));
                      },
                      icon: Icon(
                        Icons.web_rounded,
                        size: 24,
                        color: Colors.white,
                      ),
                      label: Text(
                        "Web'de Görüntüle",
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SquareEventAction(
                    icon: view.isFavorited
                        ? Icons.bookmark
                        : Icons.bookmark_outline,
                    onTap: () {
                      view.onToggleFavorite?.call(!view.isFavorited);
                    },
                  ),
                  const SizedBox(width: 6),
                  SquareEventAction(
                    icon: Icons.share_outlined,
                    onTap: view.onShare ?? () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
