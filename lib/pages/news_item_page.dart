import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:omusiber/widgets/shared/square_action.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsItemPage extends StatefulWidget {
  const NewsItemPage({super.key, required this.view});

  final NewsView view;

  @override
  State<NewsItemPage> createState() => _NewsItemPageState();
}

class _NewsItemPageState extends State<NewsItemPage> {
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Logic to determine image source (Carousel list vs Hero vs Fallback)
    final List<String> images = view.imageUrls.isNotEmpty
        ? view.imageUrls
        : (view.heroImage != null ? [view.heroImage!] : <String>[]);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // --- 1. Immersive Sliver App Bar ---
              SliverAppBar(
                expandedHeight: 300.0,
                floating: false,
                pinned: true,
                stretch: true, // Allows image to zoom on overscroll (iOS style)
                backgroundColor: colorScheme.surface,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (images.isEmpty)
                        Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.newspaper, size: 64, color: colorScheme.onSurfaceVariant),
                        )
                      else
                        CarouselSlider(
                          carouselController: _carouselController,
                          options: CarouselOptions(
                            height: 350, // Slightly taller than expandedHeight to cover overscroll
                            viewportFraction: 1.0,
                            enableInfiniteScroll: images.length > 1,
                            autoPlay: images.length > 1,
                            onPageChanged: (index, reason) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                          ),
                          items: images.map((imagePath) {
                            return _buildImage(imagePath);
                          }).toList(),
                        ),
                      
                      // Gradient Overlay at bottom of image for blending
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 80,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                            ),
                          ),
                        ),
                      ),

                      // Carousel Indicators
                      if (images.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: images.asMap().entries.map((entry) {
                              return Container(
                                width: _currentImageIndex == entry.key ? 20.0 : 6.0,
                                height: 6.0,
                                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.withOpacity(
                                    _currentImageIndex == entry.key ? 0.9 : 0.4,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // --- 2. News Content ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tags
                      if (view.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: view.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Title
                      Text(
                        view.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Metadata Row (Author & Date)
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            backgroundImage: view.authorAvatar,
                            child: view.authorAvatar == null
                                ? Icon(Icons.person, size: 18, color: colorScheme.onSurfaceVariant)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                view.authorName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (view.publishedAtText != null)
                                Text(
                                  view.publishedAtText!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      Divider(color: colorScheme.outlineVariant.withOpacity(0.5)),
                      const SizedBox(height: 24),

                      // Body Text
                      Text(
                        view.fullText ?? view.summary,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                          fontSize: 16,
                          color: colorScheme.onSurface.withOpacity(0.9),
                        ),
                      ),

                      // Extra padding for bottom bar
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- 3. Floating Bottom Action Bar ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
                border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                         if (view.detailUrl != null) {
                            launchUrl(Uri.parse(view.detailUrl!));
                         }
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.public, size: 20),
                      label: const Text("Haberi Kaynağında Oku"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Bookmark Button
                  SquareEventAction(
                    icon: view.isFavorited ? Icons.bookmark : Icons.bookmark_border,
                    onTap: () {
                      if (view.onToggleFavorite != null) {
                        view.onToggleFavorite!(!view.isFavorited);
                        // Force rebuild to show icon change (or rely on parent state management)
                        setState(() {}); 
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  // Share Button
                  SquareEventAction(
                    icon: Icons.share_outlined,
                    onTap: view.onShare ?? () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/news.webp',
            fit: BoxFit.cover,
            width: double.infinity,
          );
        },
      );
    } else {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
  }
}