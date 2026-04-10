import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/event_components/event_tag.dart';
import 'package:omusiber/widgets/no_events.dart';
import 'package:omusiber/backend/auth/auth_service.dart';
import 'package:omusiber/widgets/create_event_sheet.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';

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
  final AppStartupController _startupController = AppStartupController.instance;
  static const Duration _backgroundRefreshDelay = Duration(seconds: 4);
  static const Duration _permissionCheckDelay = Duration(seconds: 5);
  final EventRepository _repo = EventRepository();
  final Set<String> _hasAnimatedIds = {};

  bool _showBackToTopButton = false;
  bool _canCreateEvent = false;

  final List<PostView> _events = [];
  bool _isInitialLoading = true;
  String? _errorMessage;
  bool _permissionCheckQueued = false;
  bool _refreshQueued = false;
  Timer? _backgroundRefreshTimer;
  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();
    _startupController.addListener(_handleStartupChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitialData();
      _handleStartupChanged();
    });
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. Load from cache first (no network)
      final cached = await _repo.getCachedEvents();
      if (mounted) {
        setState(() {
          if (cached.isNotEmpty) {
            _isInitialLoading = false;
            _errorMessage = null;
            _events.clear();
            _events.addAll(freshWithMocks(cached));
          }
        });
      }

      // 2. Schedule refresh AFTER render
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleBackgroundRefresh();
      });
    } catch (e) {
      debugPrint("Failed to load initial events cache: $e");
      if (_events.isEmpty) {
        _scheduleBackgroundRefresh();
      }
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _repo.fetchEvents(forceRefresh: true);
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _errorMessage = null;
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
    return [...fresh];
  }

  Future<void> _checkPermissions() async {
    if (!_startupController.canUseAuthenticatedApis) {
      return;
    }
    final allowed = await AuthService().isWhitelisted();
    if (mounted) {
      setState(() {
        _canCreateEvent = allowed;
      });
    }
  }

  @override
  void dispose() {
    _startupController.removeListener(_handleStartupChanged);
    _backgroundRefreshTimer?.cancel();
    _permissionCheckTimer?.cancel();
    super.dispose();
  }

  void _handleStartupChanged() {
    if (!_startupController.canUseAuthenticatedApis) {
      return;
    }

    _scheduleBackgroundRefresh();
    if (_permissionCheckQueued) {
      return;
    }
    _permissionCheckQueued = true;
    final delay = _startupController.startupDeferral(_permissionCheckDelay);
    _permissionCheckTimer?.cancel();
    if (delay == Duration.zero) {
      unawaited(
        _checkPermissions().whenComplete(() {
          _permissionCheckQueued = false;
        }),
      );
      return;
    }
    _permissionCheckTimer = Timer(delay, () {
      if (!mounted) {
        _permissionCheckQueued = false;
        return;
      }
      unawaited(
        _checkPermissions().whenComplete(() {
          _permissionCheckQueued = false;
        }),
      );
    });
  }

  void _scheduleBackgroundRefresh() {
    final delay = _startupController.startupDeferral(_backgroundRefreshDelay);
    _backgroundRefreshTimer?.cancel();
    if (delay == Duration.zero) {
      if (_refreshQueued) {
        return;
      }
      _refreshQueued = true;
      unawaited(
        _refreshInBackground().whenComplete(() {
          _refreshQueued = false;
        }),
      );
      return;
    }
    _backgroundRefreshTimer = Timer(delay, () {
      if (!mounted || _refreshQueued) {
        return;
      }
      _refreshQueued = true;
      unawaited(
        _refreshInBackground().whenComplete(() {
          _refreshQueued = false;
        }),
      );
    });
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

  Widget _eventToCard(BuildContext context, PostView? e) {
    if (e == null) return const SizedBox.shrink();

    final imageUrl = (e.thubnailUrl.trim().isNotEmpty)
        ? e.thubnailUrl.trim()
        : (e.imageLinks.isNotEmpty ? e.imageLinks.first.trim() : '');

    final tags = e.tags.map((t) => EventTag(t, Icons.tag)).toList();

    final duration = _stringFromMeta(e, 'durationText');

    // Human readable date (No year)
    String datetime = 'Tarih yok';
    bool isPast = false;

    if (e.eventDate != null) {
      final date = e.eventDate!;
      isPast = date.isBefore(DateTime.now());

      final months = [
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
      final days = [
        '',
        'Pazartesi',
        'Salı',
        'Çarşamba',
        'Perşembe',
        'Cuma',
        'Cumartesi',
        'Pazar',
      ];

      final dayName = days[date.weekday];
      final monthName = months[date.month];
      final timeStr =
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

      datetime = '${date.day} $monthName $dayName, $timeStr';
    }

    final ticket =
        _stringFromMeta(e, 'ticketText') ??
        (e.ticketPrice <= 0
            ? 'Bilet: Ücretsiz'
            : 'Bilet: ₺${e.ticketPrice.toStringAsFixed(0)}');
    final capacity = (e.maxContributors > 0)
        ? 'Katılımcı: ${e.remainingContributors}/${e.maxContributors}'
        : null;

    final bool likedState = e.isLiked == true;
    final bool joinedState = e.isJoined == true;

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
      publisher: e.publisher,
      isLiked: likedState,
      isJoined: joinedState,
      isPast: isPast,
      isRegistrationClosed: e.isRegistrationClosed,
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
      return const _EventsLoadingState();
    }

    /* if (false && _isInitialLoading && _events.isEmpty) {
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
    } */

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
                onPressed: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateEventPage()),
                  );
                  if (created == true) {
                    await _refreshInBackground();
                  }
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

class _EventsLoadingState extends StatelessWidget {
  const _EventsLoadingState();

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
