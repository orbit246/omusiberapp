import 'dart:async';
import 'dart:ui';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:omusiber/pages/excel_viewer_page.dart';

import 'package:url_launcher/url_launcher.dart';

class NewsItemPage extends StatefulWidget {
  const NewsItemPage({super.key, required this.view});

  final NewsView view;

  @override
  State<NewsItemPage> createState() => _NewsItemPageState();
}

class _NewsItemPageState extends State<NewsItemPage> {
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  int _currentImageIndex = 0;
  late bool _isFavorited;
  late int _viewCount;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.view.isFavorited;
    _viewCount = widget.view.viewCount;

    if (widget.view.id > 0) {
      _viewCount += 1;
      unawaited(NewsFetcher().trackNewsView(widget.view.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Logic to determine image source
    final List<String> images = view.imageUrls.isNotEmpty
        ? view.imageUrls
        : (view.heroImage != null ? [view.heroImage!] : <String>[]);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true, // Required for the transparency effect
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- 1. Hero Header ---
              SliverAppBar(
                expandedHeight: 380.0,
                floating: false,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.transparent, // Let content flow
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, size: 20),
                        tooltip: 'Geri',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (images.isEmpty)
                        Container(color: colorScheme.surfaceContainerHighest)
                      else
                        CarouselSlider(
                          carouselController: _carouselController,
                          options: CarouselOptions(
                            height: 450, // Be taller to cover bounce
                            viewportFraction: 1.0,
                            enableInfiniteScroll: images.length > 1,
                            autoPlay: images.length > 1,
                            onPageChanged: (index, reason) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                          ),
                          items: images
                              .map((imagePath) => _buildImage(imagePath))
                              .toList(),
                        ),

                      // Modern soft gradient overlay
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- 2. Overlapping Content Sheet ---
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -24), // Overlap effect
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pagination Dots (moved here for cleaner look)
                        if (images.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: images.asMap().entries.map((entry) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: _currentImageIndex == entry.key
                                      ? 24.0
                                      : 8.0,
                                  height: 8.0,
                                  margin: const EdgeInsets.only(right: 6.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: _currentImageIndex == entry.key
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // Chips / Tags
                        if (view.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: view.tags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(
                                      0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: colorScheme.primary.withOpacity(
                                        0.1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    tag,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // Title
                        Text(
                          view.title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Author / Meta
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              backgroundImage: view.authorAvatar,
                              child: view.authorAvatar == null
                                  ? Icon(
                                      Icons.person,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  view.authorName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (view.publishedAtText != null)
                                  Text(
                                    view.publishedAtText!,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.remove_red_eye_outlined,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    // Use format if available, simpler fallback here or duplicate method
                                    '$_viewCount',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Body Content
                        Text(
                          view.fullText ?? view.summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            color: colorScheme.onSurface.withOpacity(0.85),
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        if (view.excelAttachments.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            "Ekler / Dosyalar",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...view.excelAttachments.map((attachment) {
                            final url = attachment['url'] as String?;
                            final name = Uri.decodeComponent(
                              url?.split('/').last ?? 'İsimsiz Dosya.xlsx',
                            );
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.table_chart,
                                  color: Colors.green,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: const Text("Excel Dosyası"),
                                trailing: const Icon(Icons.download_rounded),
                                onTap: () {
                                  if (url != null) {
                                    if (name.endsWith('.xlsx') ||
                                        name.endsWith('.xls')) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ExcelViewerPage(
                                            fileUrl: url,
                                            title: name,
                                          ),
                                        ),
                                      );
                                    } else {
                                      launchUrl(
                                        Uri.parse(url),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          }),
                        ],

                        // Extra space for FAB/BottomBar
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // --- 3. Glassy Bottom Action Bar ---
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(
                      0.8,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Share Button
                      IconButton(
                        onPressed: view.onShare,
                        icon: const Icon(Icons.share_outlined),
                        tooltip: 'Paylaş',
                      ),
                      const SizedBox(width: 4),
                      // Bookmark
                      IconButton(
                        onPressed: () {
                          final nextValue = !_isFavorited;
                          setState(() {
                            _isFavorited = nextValue;
                          });
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
                        icon: Icon(
                          _isFavorited
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                        ),
                        color: _isFavorited ? colorScheme.primary : null,
                      ),

                      const Spacer(),

                      // Primary Action: Open Source
                      if (view.detailUrl != null)
                        FilledButton.icon(
                          onPressed: () =>
                              launchUrl(Uri.parse(view.detailUrl!)),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Habere Git'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
      return Image.asset(imagePath, fit: BoxFit.cover, width: double.infinity);
    }
  }
}
