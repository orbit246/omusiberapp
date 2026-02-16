import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/event_components/event_tag.dart';
import 'package:omusiber/widgets/no_events.dart';
import 'package:omusiber/backend/auth/auth_service.dart';
import 'package:omusiber/widgets/create_event_sheet.dart';
import 'package:omusiber/backend/mock_events.dart';

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

// --- 2. MAIN VIEW ---
class EventsTabView extends StatefulWidget {
  const EventsTabView({super.key});

  @override
  State<EventsTabView> createState() => _EventsTabViewState();
}

class _EventsTabViewState extends State<EventsTabView> {
  final EventRepository _repo = EventRepository();
  final Set<String> _hasAnimatedIds = {};

  bool _showBackToTopButton = false;
  bool _canCreateEvent = false;

  final List<PostView> _events = [];
  bool _isInitialLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _checkPermissions();
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. Load from cache first (no network)
      final cached = await _repo.getCachedEvents();
      if (mounted) {
        setState(() {
          if (cached.isNotEmpty) {
            _isInitialLoading = false;
            _events.clear();
            _events.addAll(freshWithMocks(cached));
          }
        });
      }

      // 2. Schedule refresh AFTER render
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshInBackground();
      });
    } catch (e) {
      debugPrint("Failed to load initial events cache: $e");
      if (_events.isEmpty) {
        _refreshInBackground();
      }
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _repo.fetchEvents(forceRefresh: true);
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _events.clear();
          _events.addAll(freshWithMocks(fresh));
        });
      }
    } catch (e) {
      debugPrint("Background refresh failed: $e");
      if (mounted && _events.isEmpty) {
        setState(() {
          _isInitialLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  List<PostView> freshWithMocks(List<PostView> fresh) {
    return [...mockEvents, ...fresh];
  }

  Future<void> _checkPermissions() async {
    final allowed = await AuthService().isWhitelisted();
    if (mounted) {
      setState(() {
        _canCreateEvent = allowed;
      });
    }
  }

  @override
  void dispose() {
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
      onBookmark: (isBookmarked) {
        if (!isBookmarked) return;
        unawaited(_repo.trackEventLike(e.id, isLiked: true));
      },
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
    await _refreshInBackground();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading && _events.isEmpty) {
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

    if (_errorMessage != null && _events.isEmpty) {
      return Center(child: Text('Bir hata oluştu: $_errorMessage'));
    }

    final events = _events;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.axis == Axis.vertical) {
            if (scrollInfo.metrics.pixels >= 500) {
              if (!_showBackToTopButton) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_showBackToTopButton) {
                    setState(() => _showBackToTopButton = true);
                  }
                });
              }
            } else {
              if (_showBackToTopButton) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _showBackToTopButton) {
                    setState(() => _showBackToTopButton = false);
                  }
                });
              }
            }
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          displacement: 20,
          edgeOffset: 0,
          child: CustomScrollView(
            key: const PageStorageKey('events_tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              if (events.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      Expanded(child: Center(child: NoEventsFoundWidget())),
                      _buildFooter(context),
                      const SizedBox(height: 80),
                    ],
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final event = events[index];
                    final bool hasAnimated = _hasAnimatedIds.contains(event.id);
                    final bool shouldAnimate = !hasAnimated;

                    if (shouldAnimate) {
                      _hasAnimatedIds.add(event.id);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SlideInEntry(
                        key: ValueKey(event.id),
                        animate: shouldAnimate,
                        child: _eventToCard(context, event),
                      ),
                    );
                  }, childCount: events.length),
                ),

              SliverToBoxAdapter(child: _buildFooter(context)),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Built by ",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            "NortixLabs",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            " with ",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Icon(
            Icons.favorite,
            color: Theme.of(context).colorScheme.primary,
            size: 14,
          ),
        ],
      ),
    );
  }
}
