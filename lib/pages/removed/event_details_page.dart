import 'dart:ui';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:share_plus/share_plus.dart';

class EventDetailsPage extends StatefulWidget {
  const EventDetailsPage({super.key, required this.event});

  final PostView event;

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  int _currentImageIndex = 0;
  bool _isFavorited = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Logic to determine image source
    final List<String> images = event.imageLinks.isNotEmpty
        ? event.imageLinks
        : (event.thubnailUrl.isNotEmpty ? [event.thubnailUrl] : <String>[]);

    // Extract metadata
    final datetime =
        event.metadata['datetimeText']?.toString() ?? 'Tarih Belirtilmemiş';
    final duration = event.metadata['durationText']?.toString();
    final ticketText =
        event.metadata['ticketText']?.toString() ??
        (event.ticketPrice <= 0
            ? 'Ücretsiz'
            : '₺${event.ticketPrice.toStringAsFixed(0)}');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
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
                backgroundColor: Colors.transparent,
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
                            height: 480,
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

                      // Gradient overlay
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
                  offset: const Offset(0, -24),
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
                        // Pagination Dots
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

                        // Tags
                        if (event.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: event.tags.map((tag) {
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
                          event.title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Info Rows (Location, Date, Ticket)
                        _buildFeatureRow(
                          context,
                          Icons.calendar_today_rounded,
                          datetime,
                          subtitle: duration,
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureRow(
                          context,
                          Icons.location_on_rounded,
                          event.location,
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureRow(
                          context,
                          Icons.confirmation_number_rounded,
                          ticketText,
                          subtitle: event.maxContributors > 0
                              ? '${event.remainingContributors}/${event.maxContributors} Kişilik Kontenjan'
                              : null,
                        ),

                        const SizedBox(height: 28),
                        const Divider(height: 1),
                        const SizedBox(height: 28),

                        // Description Title
                        Text(
                          "Hakkında",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Body Content
                        Text(
                          event.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            color: colorScheme.onSurface.withOpacity(0.85),
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                          ),
                        ),

                        // Extra space for FAB
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
                      // Share
                      IconButton(
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(
                              text: '${event.title}\n${event.location}',
                            ),
                          );
                        },
                        icon: const Icon(Icons.share_outlined),
                        tooltip: 'Paylaş',
                      ),
                      const SizedBox(width: 4),
                      // Bookmark
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isFavorited = !_isFavorited;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _isFavorited
                                    ? 'Kaydedildi'
                                    : 'Kayıt kaldırıldı',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: Icon(
                          _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                        ),
                        color: _isFavorited ? colorScheme.primary : null,
                      ),

                      const Spacer(),

                      // Primary Action
                      FilledButton.icon(
                        onPressed: () {
                          // Implement Join Logic
                        },
                        icon: const Icon(Icons.event_available, size: 18),
                        label: const Text('Etkinliğe Katıl'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
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

  Widget _buildFeatureRow(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage(String imagePath) {
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 50,
                color: Colors.grey,
              ),
            ),
          );
        },
      );
    } else {
      return Image.asset(imagePath, fit: BoxFit.cover, width: double.infinity);
    }
  }
}
