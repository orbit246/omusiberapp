import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/backend/share_service.dart';
import 'package:omusiber/pages/new_view/controllers/events_tab_controller.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/event_components/event_tag.dart';
import 'package:omusiber/widgets/no_events.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';
import 'package:omusiber/widgets/shared/content_filter_bar.dart';

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
  late final EventsTabController _controller;
  final Set<String> _hasAnimatedIds = {};
  EventFilters _filters = const EventFilters();
  bool _showBackToTopButton = false;

  @override
  void initState() {
    super.initState();
    _controller = EventsTabController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.loadInitialData());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
          filters: _filters,
          showBackToTopButton: _showBackToTopButton,
          onFiltersChanged: (filters) => setState(() => _filters = filters),
          onRefresh: _controller.refresh,
          onScrollNotification: _handleScrollNotification,
          onBackToTop: _scrollToTop,
          onLike: (event, isLiked) =>
              unawaited(_controller.toggleEventLike(event.id, isLiked)),
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

class EventFilters {
  const EventFilters({
    this.sortKey = 'upcoming',
    this.scope,
    this.organizerType,
    this.pricingType,
    this.eventType,
  });

  final String sortKey;
  final String? scope;
  final String? organizerType;
  final String? pricingType;
  final String? eventType;

  bool get hasActiveFilters =>
      scope != null ||
      organizerType != null ||
      pricingType != null ||
      eventType != null;

  int get activeFilterCount =>
      [scope, organizerType, pricingType, eventType].whereType<String>().length;

  String get sortLabel => switch (sortKey) {
    'newest' => 'En Yeni',
    'oldest' => 'En Eski',
    _ => 'Yaklaşan',
  };

  String get filterSummary {
    final parts = <String>[];
    if (scope != null) parts.add(scope == 'samsun' ? 'Samsun İçi' : 'Türkiye');
    if (organizerType != null) {
      parts.add(organizerType == 'official' ? 'Resmi' : 'Topluluk');
    }
    if (pricingType != null) {
      parts.add(pricingType == 'paid' ? 'Ücretli' : 'Ücretsiz');
    }
    if (eventType != null) {
      parts.add(
        _eventTypeOptions
                .where((option) => option.value == eventType)
                .firstOrNull
                ?.label ??
            eventType!,
      );
    }
    return parts.isEmpty ? 'Tümü' : parts.join(' • ');
  }

  List<String> get selectedFilterLabels {
    final labels = <String>[];
    if (scope != null) {
      labels.add(scope == 'samsun' ? 'Samsun İçi' : 'Türkiye Geneli');
    }
    if (organizerType != null) {
      labels.add(organizerType == 'official' ? 'Resmi' : 'Topluluk');
    }
    if (pricingType != null) {
      labels.add(pricingType == 'paid' ? 'Ücretli' : 'Ücretsiz');
    }
    if (eventType != null) {
      labels.add(
        _eventTypeOptions
                .where((option) => option.value == eventType)
                .firstOrNull
                ?.label ??
            eventType!,
      );
    }
    return labels;
  }

  bool matches(PostView event) {
    return (scope == null || event.scope == scope) &&
        (organizerType == null || event.organizerType == organizerType) &&
        (pricingType == null || event.pricingType == pricingType) &&
        (eventType == null || event.eventType == eventType);
  }

  List<PostView> sortEvents(Iterable<PostView> source) {
    final events = source.toList(growable: false);
    final sorted = [...events];
    final now = DateTime.now();

    DateTime? sortDate(PostView event) {
      if (event.eventDate != null) return event.eventDate;
      final raw = event.metadata['createdAt'] ?? event.metadata['eventDate'];
      return raw == null ? null : DateTime.tryParse(raw.toString());
    }

    sorted.sort((left, right) {
      final leftDate = sortDate(left);
      final rightDate = sortDate(right);
      if (leftDate == null && rightDate == null) return 0;
      if (leftDate == null) return 1;
      if (rightDate == null) return -1;

      if (sortKey == 'upcoming') {
        final leftUpcoming = !leftDate.isBefore(now);
        final rightUpcoming = !rightDate.isBefore(now);
        if (leftUpcoming != rightUpcoming) {
          return leftUpcoming ? -1 : 1;
        }
        return leftUpcoming
            ? leftDate.compareTo(rightDate)
            : rightDate.compareTo(leftDate);
      }

      return sortKey == 'oldest'
          ? leftDate.compareTo(rightDate)
          : rightDate.compareTo(leftDate);
    });
    return sorted;
  }
}

class _EventFilterOption {
  const _EventFilterOption(this.value, this.label);

  final String value;
  final String label;
}

const _eventScopeOptions = [
  _EventFilterOption('samsun', 'Samsun İçi'),
  _EventFilterOption('turkiye', 'Türkiye Geneli'),
];

const _eventOrganizerOptions = [
  _EventFilterOption('official', 'Resmi'),
  _EventFilterOption('community', 'Topluluk'),
];

const _eventPricingOptions = [
  _EventFilterOption('paid', 'Ücretli'),
  _EventFilterOption('free', 'Ücretsiz'),
];

const _eventTypeOptions = [
  _EventFilterOption('conference', 'Konferans'),
  _EventFilterOption('seminar', 'Seminer'),
  _EventFilterOption('workshop', 'Atölye'),
  _EventFilterOption('training', 'Eğitim'),
  _EventFilterOption('competition', 'Yarışma'),
  _EventFilterOption('social', 'Sosyal'),
  _EventFilterOption('culture', 'Kültür-Sanat'),
  _EventFilterOption('sports', 'Spor'),
  _EventFilterOption('career', 'Kariyer'),
  _EventFilterOption('other', 'Diğer'),
];

class EventsTabContent extends StatelessWidget {
  const EventsTabContent({
    super.key,
    required this.events,
    required this.isInitialLoading,
    required this.errorMessage,
    required this.hasAnimatedIds,
    required this.filters,
    required this.showBackToTopButton,
    required this.onRefresh,
    required this.onScrollNotification,
    required this.onBackToTop,
    required this.onFiltersChanged,
    required this.onLike,
    required this.onShare,
    required this.onOpenEvent,
  });

  final List<PostView> events;
  final bool isInitialLoading;
  final String? errorMessage;
  final Set<String> hasAnimatedIds;
  final EventFilters filters;
  final bool showBackToTopButton;
  final Future<void> Function() onRefresh;
  final ValueChanged<ScrollNotification> onScrollNotification;
  final VoidCallback onBackToTop;
  final ValueChanged<EventFilters> onFiltersChanged;
  final void Function(PostView event, bool isLiked) onLike;
  final ValueChanged<PostView> onShare;
  final ValueChanged<PostView> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading && events.isEmpty) {
      return const EventsLoadingState();
    }

    if (errorMessage != null && events.isEmpty) {
      return Center(child: Text(errorMessage!));
    }

    final visibleEvents = filters.sortEvents(events.where(filters.matches));

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
              SliverToBoxAdapter(
                child: _EventFilterBar(
                  filters: filters,
                  onFiltersChanged: onFiltersChanged,
                ),
              ),
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
              else if (visibleEvents.isEmpty)
                const SliverToBoxAdapter(
                  child: ContentFilterEmptyState(
                    title: 'Bu filtrelerle eşleşen etkinlik yok.',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final event = visibleEvents[index];
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
                          onLike: (isLiked) => onLike(event, isLiked),
                          onShare: () => onShare(event),
                          onOpen: () => onOpenEvent(event),
                        ),
                      ),
                    );
                  }, childCount: visibleEvents.length),
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

class _EventFilterBar extends StatelessWidget {
  const _EventFilterBar({
    required this.filters,
    required this.onFiltersChanged,
  });

  final EventFilters filters;
  final ValueChanged<EventFilters> onFiltersChanged;

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<EventFilters>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _EventFilterSheet(initialFilters: filters),
    );
    if (result != null) onFiltersChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return ContentFilterBar(
      sortLabel: filters.sortLabel,
      filterLabel: 'Filtrele',
      hasActiveFilters: filters.hasActiveFilters,
      selectedItems: filters.selectedFilterLabels,
      onOpen: () => _openFilterSheet(context),
      onClear: () => onFiltersChanged(const EventFilters()),
    );
  }
}

class _EventFilterSheet extends StatefulWidget {
  const _EventFilterSheet({required this.initialFilters});

  final EventFilters initialFilters;

  @override
  State<_EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<_EventFilterSheet> {
  late String _sortKey = widget.initialFilters.sortKey;
  late String? _scope = widget.initialFilters.scope;
  late String? _organizerType = widget.initialFilters.organizerType;
  late String? _pricingType = widget.initialFilters.pricingType;
  late String? _eventType = widget.initialFilters.eventType;

  Widget _buildGroup(
    BuildContext context,
    String title,
    List<_EventFilterOption> options,
    String? selected,
    ValueChanged<String?> onChanged, {
    bool includeAll = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (includeAll)
              _buildChoice(
                context,
                'Tümü',
                selected == null,
                () => onChanged(null),
              ),
            ...options.map(
              (option) => _buildChoice(
                context,
                option.label,
                selected == option.value,
                () => onChanged(option.value),
              ),
            ),
          ],
        ),
        Divider(
          height: 28,
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ],
    );
  }

  Widget _buildChoice(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onPressed,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onPressed(),
      labelStyle: TextStyle(
        color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.45,
      ),
      side: BorderSide(
        color: selected
            ? colorScheme.primary
            : colorScheme.outlineVariant.withValues(alpha: 0.7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Etkinlik filtreleri',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            _buildGroup(
              context,
              'Sıralama',
              const [
                _EventFilterOption('upcoming', 'Yaklaşan'),
                _EventFilterOption('newest', 'En Yeni'),
                _EventFilterOption('oldest', 'En Eski'),
              ],
              _sortKey,
              (value) => setState(() => _sortKey = value ?? 'upcoming'),
              includeAll: false,
            ),
            _buildGroup(
              context,
              'Konum',
              _eventScopeOptions,
              _scope,
              (value) => setState(() => _scope = value),
            ),
            _buildGroup(
              context,
              'Düzenleyen',
              _eventOrganizerOptions,
              _organizerType,
              (value) => setState(() => _organizerType = value),
            ),
            _buildGroup(
              context,
              'Ücret',
              _eventPricingOptions,
              _pricingType,
              (value) => setState(() => _pricingType = value),
            ),
            _buildGroup(
              context,
              'Etkinlik türü',
              _eventTypeOptions,
              _eventType,
              (value) => setState(() => _eventType = value),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  EventFilters(
                    sortKey: _sortKey,
                    scope: _scope,
                    organizerType: _organizerType,
                    pricingType: _pricingType,
                    eventType: _eventType,
                  ),
                ),
                child: const Text('Filtreleri uygula'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventListCard extends StatelessWidget {
  const EventListCard({
    super.key,
    required this.event,
    required this.onLike,
    required this.onShare,
    required this.onOpen,
  });

  final PostView event;
  final ValueChanged<bool> onLike;
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
        (event.pricingType == 'paid' ? 'Biletli' : 'Ücretsiz');
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
      likeCount: event.likeCount,
      isJoined: event.isJoined == true,
      isPast: isPast,
      isRegistrationClosed: event.isRegistrationClosed,
      isExternalRegistration: event.usesExternalRegistration,
      onJoin: onOpen,
      onLike: onLike,
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
    return 'Yükleniyor...';
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
