import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/no_events.dart';
import 'package:omusiber/backend/auth/auth_service.dart';
import 'package:omusiber/widgets/create_event_sheet.dart';

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
// --- 2. CUSTOM PHYSICS (Removed to fix overscroll error) ---
// We will use standard AlwaysScrollableScrollPhysics instead.

// --- 3. MAIN VIEW ---
class EventsTabView extends StatefulWidget {
  const EventsTabView({super.key});

  @override
  State<EventsTabView> createState() => _EventsTabViewState();
}

class _EventsTabViewState extends State<EventsTabView> {
  final EventRepository _repo = EventRepository();
  final Set<String> _hasAnimatedIds = {};

  // No explicit ScrollController; we rely on the PrimaryScrollController provided by NestedScrollView.
  // This allows the inner list to work correctly with the outer NestedScrollView behavior.

  bool _showBackToTopButton = false;
  bool _canCreateEvent = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    print("DEBUG: Checking permissions...");
    final allowed = await AuthService().isWhitelisted();
    print("DEBUG: isWhitelisted result: $allowed");
    if (mounted) {
      setState(() {
        _canCreateEvent = allowed;
        print("DEBUG: Updated _canCreateEvent to: $_canCreateEvent");
      });
    }
  }

  @override
  void dispose() {
    // No controller to dispose
    super.dispose();
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
          MaterialPageRoute(builder: (_) => EventDetailsPage(event: e)),
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

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      _showToast("Yeni etkinlik bulunamadı", Icons.info_rounded, false);
    }
  }

  void _showToast(String msg, IconData icon, bool isSuccess) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const StadiumBorder(),
        backgroundColor: isSuccess
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        elevation: 6,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSuccess
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSuccess
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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

          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.axis == Axis.vertical) {
                // Determine if we show the back-to-top button
                if (scrollInfo.metrics.pixels >= 500) {
                  if (!_showBackToTopButton)
                    setState(() => _showBackToTopButton = true);
                } else {
                  if (_showBackToTopButton)
                    setState(() => _showBackToTopButton = false);
                }
              }
              return false; // let the notification bubble up to NestedScrollView
            },
            child: CustomScrollView(
              // No 'controller' property is set, so it uses the inherited PrimaryScrollController
              key: const PageStorageKey('events_tab'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _handleRefresh,
                  refreshTriggerPullDistance: 60.0,
                  refreshIndicatorExtent: 40.0,
                ),
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
                      final bool hasAnimated = _hasAnimatedIds.contains(
                        event.id,
                      );
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
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Whitelisting Check FAB
          if (_canCreateEvent)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton(
                heroTag: 'createEvent',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CreateEventSheet(),
                  );
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),

          if (_showBackToTopButton)
            FloatingActionButton(
              heroTag: 'backToTop',
              onPressed: _scrollToTop,
              mini: true,
              child: const Icon(Icons.arrow_upward),
            ),
        ],
      ),
    );
  }
}
