import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/backend/share_service.dart';
import 'package:omusiber/pages/new_view/controllers/events_tab_controller.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/event_components/event_tag.dart';
import 'package:omusiber/widgets/no_events.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';

class SlideInEntry extends StatefulWidget {
  const SlideInEntry({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
  });

  final Widget child;
  final Duration delay;
  final bool animate;

  @override
  State<SlideInEntry> createState() => _SlideInEntryState();
}

class _SlideInEntryState extends State<SlideInEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );

    if (!widget.animate) {
      _controller.value = 1.0;
    } else {
      _runAnimation();
    }
  }

  Future<void> _runAnimation() async {
    if (widget.delay > Duration.zero) {
      await Future.delayed(widget.delay);
    }
    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return widget.child;
    }

    return SizeTransition(
      sizeFactor: _sizeAnimation,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(position: _offsetAnimation, child: widget.child),
      ),
    );
  }
}

class EventsTabView extends StatefulWidget {
  const EventsTabView({super.key});

  @override
  State<EventsTabView> createState() => _EventsTabViewState();
}

class _EventsTabViewState extends State<EventsTabView> {
  static const int _imagePrefetchLimit = 5;

  late final EventsTabController _controller;
  final Set<String> _hasAnimatedIds = {};
  bool _showBackToTopButton = false;

  @override
  void initState() {
    super.initState();
    _controller = EventsTabController()..addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.loadInitialData());
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _precacheEventImages(_controller.events);
  }

  void _scrollToTop() {
    final primaryController = PrimaryScrollController.of(context);
    if (primaryController.hasClients) {
      primaryController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _precacheEventImages(List<PostView> items) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final event in items.take(_imagePrefetchLimit)) {
        final url = eventImageUrl(event);
        if (url.isEmpty) continue;

        unawaited(precacheImage(CachedNetworkImageProvider(url), context));
      }
    });
  }

  void _handleScrollNotification(ScrollNotification scrollInfo) {
    if (scrollInfo.metrics.axis != Axis.vertical) {
      return;
    }

    final shouldShow = scrollInfo.metrics.pixels >= 500;
    if (shouldShow == _showBackToTopButton) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showBackToTopButton != shouldShow) {
        setState(() => _showBackToTopButton = shouldShow);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return EventsTabContent(
          events: _controller.events,
          isInitialLoading: _controller.isInitialLoading,
          errorMessage: _controller.errorMessage,
          hasAnimatedIds: _hasAnimatedIds,
          showBackToTopButton: _showBackToTopButton,
          onRefresh: _controller.refresh,
          onScrollNotification: _handleScrollNotification,
          onBackToTop: _scrollToTop,
          onBookmark: (event, isBookmarked) {
            if (!isBookmarked) return;
            unawaited(_controller.trackEventLike(event.id, isLiked: true));
          },
          onShare: (event) =>
              unawaited(ShareService.shareEvent(context, event)),
          onOpenEvent: (event) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EventDetailsPage(event: event)),
            );
          },
        );
      },
    );
  }
}

class EventsTabContent extends StatelessWidget {
  const EventsTabContent({
    super.key,
    required this.events,
    required this.isInitialLoading,
    required this.errorMessage,
    required this.hasAnimatedIds,
    required this.showBackToTopButton,
    required this.onRefresh,
    required this.onScrollNotification,
    required this.onBackToTop,
    required this.onBookmark,
    required this.onShare,
    required this.onOpenEvent,
  });

  final List<PostView> events;
  final bool isInitialLoading;
  final String? errorMessage;
  final Set<String> hasAnimatedIds;
  final bool showBackToTopButton;
  final Future<void> Function() onRefresh;
  final ValueChanged<ScrollNotification> onScrollNotification;
  final VoidCallback onBackToTop;
  final void Function(PostView event, bool isBookmarked) onBookmark;
  final ValueChanged<PostView> onShare;
  final ValueChanged<PostView> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading && events.isEmpty) {
      return const EventsLoadingState();
    }

    if (errorMessage != null && events.isEmpty) {
      return Center(child: Text('Bir hata oluştu: $errorMessage'));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          onScrollNotification(scrollInfo);
          return false;
        },
        child: RefreshIndicator(
          onRefresh: onRefresh,
          displacement: 20,
          edgeOffset: 0,
          child: CustomScrollView(
            cacheExtent: 900,
            key: const PageStorageKey('events_tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (events.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      Expanded(child: Center(child: NoEventsFoundWidget())),
                      SizedBox(height: 80),
                    ],
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final event = events[index];
                    final hasAnimated = hasAnimatedIds.contains(event.id);
                    final shouldAnimate = !hasAnimated;

                    if (shouldAnimate) {
                      hasAnimatedIds.add(event.id);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SlideInEntry(
                        key: ValueKey(event.id),
                        animate: shouldAnimate,
                        child: EventListCard(
                          event: event,
                          onBookmark: (isBookmarked) =>
                              onBookmark(event, isBookmarked),
                          onShare: () => onShare(event),
                          onOpen: () => onOpenEvent(event),
                        ),
                      ),
                    );
                  }, childCount: events.length),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
      floatingActionButton: showBackToTopButton
          ? FloatingActionButton(
              heroTag: 'backToTop',
              onPressed: onBackToTop,
              mini: true,
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }
}

class EventListCard extends StatelessWidget {
  const EventListCard({
    super.key,
    required this.event,
    required this.onBookmark,
    required this.onShare,
    required this.onOpen,
  });

  final PostView event;
  final ValueChanged<bool> onBookmark;
  final VoidCallback onShare;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final imageUrl = eventImageUrl(event);
    final tags = event.tags.map((tag) => EventTag(tag, Icons.tag)).toList();
    final duration = stringFromMeta(event, 'durationText');
    final eventDate = event.eventDate;
    final isPast = eventDate?.isBefore(DateTime.now()) ?? false;

    final ticket =
        stringFromMeta(event, 'ticketText') ??
        (event.ticketPrice <= 0
            ? 'Bilet: Ücretsiz'
            : 'Bilet: ₺${event.ticketPrice.toStringAsFixed(0)}');
    final capacity = (event.maxContributors > 0)
        ? 'Katılımcı: ${event.remainingContributors}/${event.maxContributors}'
        : null;

    return EventCard(
      title: event.title,
      datetimeText: eventDateText(eventDate),
      location: event.location,
      imageUrl: imageUrl,
      durationText: duration,
      ticketText: ticket,
      capacityText: capacity,
      description: event.description,
      tags: tags,
      publisher: event.publisher,
      isLiked: event.isLiked == true,
      isJoined: event.isJoined == true,
      isPast: isPast,
      isRegistrationClosed: event.isRegistrationClosed,
      onJoin: onOpen,
      onBookmark: onBookmark,
      onShare: onShare,
    );
  }
}

String eventImageUrl(PostView event) {
  return event.thubnailUrl.trim().isNotEmpty
      ? event.thubnailUrl.trim()
      : (event.imageLinks.isNotEmpty ? event.imageLinks.first.trim() : '');
}

String? stringFromMeta(PostView event, String key) {
  final value = event.metadata[key];
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return value.toString();
}

String eventDateText(DateTime? date) {
  if (date == null) {
    return 'Tarih yok';
  }

  const months = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  const days = [
    '',
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '${date.day} ${months[date.month]} ${days[date.weekday]}, $time';
}

class EventsLoadingState extends StatelessWidget {
  const EventsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey('events_tab_loading'),
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(
                        height: 172,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      SizedBox(height: 14),
                      AppSkeleton(
                        height: 16,
                        width: 180,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      SizedBox(height: 10),
                      AppSkeleton(
                        height: 10,
                        width: 132,
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      SizedBox(height: 10),
                      AppSkeleton(
                        height: 10,
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      SizedBox(height: 18),
                      AppSkeleton(
                        height: 38,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }, childCount: 3),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}
