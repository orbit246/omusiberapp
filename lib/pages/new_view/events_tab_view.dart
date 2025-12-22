import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/no_events.dart';

// --- 1. ANIMATION WRAPPER (Copied from NewsTabView) ---
class SlideInEntry extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool animate;

  const SlideInEntry({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
  });

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

  void _runAnimation() async {
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

// --- 2. CUSTOM PHYSICS (Copied from NewsTabView) ---
class RefreshSafeScrollPhysics extends BouncingScrollPhysics {
  const RefreshSafeScrollPhysics({super.parent});

  @override
  RefreshSafeScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return RefreshSafeScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }
    if (value < -120.0) {
      return value - (-120.0);
    }
    return super.applyBoundaryConditions(position, value);
  }
}

// --- 3. MAIN VIEW ---
class EventsTabView extends StatefulWidget {
  const EventsTabView({super.key});

  @override
  State<EventsTabView> createState() => _EventsTabViewState();
}

class _EventsTabViewState extends State<EventsTabView> {
  final EventRepository _repo = EventRepository();
  final Set<String> _hasAnimatedIds = {};

  final ScrollController _scrollController = ScrollController();
  bool _showBackToTopButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset >= 500) {
        if (!_showBackToTopButton) setState(() => _showBackToTopButton = true);
      } else {
        if (_showBackToTopButton) setState(() => _showBackToTopButton = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
    );
  }

  // Same helper mapping as before
  Widget _eventToCard(BuildContext context, PostView e) {
    final imageUrl = (e.thubnailUrl.trim().isNotEmpty)
        ? e.thubnailUrl.trim()
        : (e.imageLinks.isNotEmpty ? e.imageLinks.first.trim() : '');

    final tags = e.tags.map((t) => EventTag(t, Icons.tag)).toList();

    final duration = _stringFromMeta(e, 'durationText');
    final datetime = _stringFromMeta(e, 'datetimeText') ?? 'Tarih yok';
    final ticket =
        _stringFromMeta(e, 'ticketText') ??
        (e.ticketPrice <= 0
            ? 'Bilet: Ücretsiz'
            : 'Bilet: ₺${e.ticketPrice.toStringAsFixed(0)}');
    final capacity = (e.maxContributors > 0)
        ? 'Katılımcı: ${e.remainingContributors}/${e.maxContributors}'
        : null;

    return EventCard(
      title: e.title,
      datetimeText: datetime,
      location: e.location,
      imageUrl: imageUrl,
      durationText: duration,
      ticketText: ticket,
      capacityText: capacity,
      description: e.description,
      tags: tags,
      onJoin: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailsPage()),
        );
      },
      onBookmark: () {},
      onShare: () {},
    );
  }

  String? _stringFromMeta(PostView e, String key) {
    final v = e.metadata[key];
    if (v == null) return null;
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<PostView>>(
        stream: _repo.eventsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Etkinlikler yükleniyor",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final events = snapshot.data ?? [];

          return CustomScrollView(
            controller: _scrollController,
            key: const PageStorageKey('events_tab'),
            physics: const RefreshSafeScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Use standard refresh indicator for Slivers if needed,
              // but since it's a Stream, explicit refresh isn't strictly necessary
              // unless we want to force re-fetch or clear cache (which eventsStream doesn't strictly use in the same way).
              // However, to be "similar to news tab", we can keep the visual control even if it doesn't do much for a stream.
              // Or we can simple omit it if the stream is live.
              // Usually Stream + Refresh is redundant for Firestore snapshots unless limits are Involved.
              // I'll keep the sliver structure but maybe no refresh control needed for Stream
              // OR I can use it to re-trigger something if needed.
              // Let's stick to the visual structure.
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              if (events.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child:
                        NoEventsFoundWidget(), // Removed onRefresh as stream updates automatically
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final event = events[index];

                    // Animation Logic
                    final bool hasAnimated = _hasAnimatedIds.contains(event.id);
                    // If it hasn't animated yet, we animate it now
                    final bool shouldAnimate = !hasAnimated;

                    if (shouldAnimate) {
                      _hasAnimatedIds.add(event.id);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 12.0,
                        left: 16.0,
                        right: 16.0,
                      ),
                      child: SlideInEntry(
                        key: ValueKey(event.id),
                        animate: shouldAnimate,
                        child: _eventToCard(context, event),
                      ),
                    );
                  }, childCount: events.length),
                ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          );
        },
      ),
      floatingActionButton: _showBackToTopButton
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              mini: true,
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }
}
