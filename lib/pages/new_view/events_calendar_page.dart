import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:omusiber/backend/calendar_sync_service.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/colors/app_colors.dart';
import 'package:omusiber/pages/new_view/events_tab_view.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:table_calendar/table_calendar.dart';

class EventsCalendarPage extends StatefulWidget {
  const EventsCalendarPage({
    super.key,
    this.initialEvents = const <PostView>[],
  });

  final List<PostView> initialEvents;

  @override
  State<EventsCalendarPage> createState() => _EventsCalendarPageState();
}

class _EventsCalendarPageState extends State<EventsCalendarPage> {
  final EventRepository _repo = EventRepository();
  late List<PostView> _allEvents;
  final Map<DateTime, List<PostView>> _eventsByDate = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
    _allEvents = [...widget.initialEvents];
    _indexEvents(_allEvents);

    if (_allEvents.isEmpty) {
      _loadEvents();
    } else {
      _selectInitialDay();
    }
  }

  void _selectInitialDay() {
    final today = _normalizeDate(DateTime.now());
    if (_eventsByDate.containsKey(today)) {
      _selectedDay = today;
      _focusedDay = today;
      return;
    }

    // If today has no events, check if there are upcoming events
    final futureDates = _eventsByDate.keys
        .where((d) => !d.isBefore(today))
        .toList()
      ..sort();

    if (futureDates.isNotEmpty) {
      _selectedDay = futureDates.first;
      _focusedDay = futureDates.first;
    } else if (_eventsByDate.isNotEmpty) {
      final sortedDates = _eventsByDate.keys.toList()..sort();
      _selectedDay = sortedDates.last;
      _focusedDay = sortedDates.last;
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _indexEvents(List<PostView> events) {
    _eventsByDate.clear();
    for (final event in events) {
      final date = event.eventDate;
      if (date != null) {
        final key = _normalizeDate(date);
        _eventsByDate.putIfAbsent(key, () => <PostView>[]).add(event);
      }
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final cached = await _repo.getCachedEvents();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _allEvents = cached;
          _indexEvents(_allEvents);
          _selectInitialDay();
        });
      }

      final fresh = await _repo.fetchEvents(fallbackToCacheOnError: true);
      if (mounted) {
        setState(() {
          _allEvents = fresh;
          _indexEvents(_allEvents);
          _selectInitialDay();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<PostView> _getEventsForDay(DateTime day) {
    return _eventsByDate[_normalizeDate(day)] ?? const <PostView>[];
  }

  void _goToToday() {
    final today = _normalizeDate(DateTime.now());
    setState(() {
      _selectedDay = today;
      _focusedDay = today;
    });
  }

  void _goToNextUpcomingEvent() {
    final today = _normalizeDate(_selectedDay);
    final upcomingDates = _eventsByDate.keys
        .where((d) => d.isAfter(today))
        .toList()
      ..sort();

    if (upcomingDates.isNotEmpty) {
      setState(() {
        _selectedDay = upcomingDates.first;
        _focusedDay = upcomingDates.first;
      });
    } else if (_eventsByDate.isNotEmpty) {
      final allSorted = _eventsByDate.keys.toList()..sort();
      setState(() {
        _selectedDay = allSorted.first;
        _focusedDay = allSorted.first;
      });
    }
  }

  String _formatTurkishDate(DateTime date) {
    try {
      return DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(date);
    } catch (_) {
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
      return '${date.day} ${months[date.month]} ${date.year}, ${days[date.weekday]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selectedEvents = _getEventsForDay(_selectedDay);

    final turkishDateFormatted = _formatTurkishDate(_selectedDay);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Etkinlik Takvimi'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Geri',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today_rounded, size: 18),
            label: const Text('Bugün'),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading && _allEvents.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Calendar Container
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.cardBorder(theme.brightness),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.2 : 0.04,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TableCalendar<PostView>(
                        firstDay: DateTime(2020, 1, 1),
                        lastDay: DateTime(2035, 12, 31),
                        focusedDay: _focusedDay,
                        currentDay: DateTime.now(),
                        locale: 'tr_TR',
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        calendarFormat: CalendarFormat.month,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Ay',
                        },
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        eventLoader: _getEventsForDay,
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                          });
                        },
                        headerStyle: HeaderStyle(
                          titleCentered: true,
                          formatButtonVisible: false,
                          titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                          leftChevronIcon: Icon(
                            Icons.chevron_left_rounded,
                            color: colorScheme.onSurface,
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurface,
                          ),
                          headerMargin: const EdgeInsets.only(bottom: 8),
                          headerPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: theme.textTheme.bodySmall!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          weekendStyle: theme.textTheme.bodySmall!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.error.withValues(alpha: 0.8),
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          isTodayHighlighted: true,
                          outsideDaysVisible: true,
                          defaultTextStyle: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.error.withValues(alpha: 0.8),
                          ),
                          outsideTextStyle: theme.textTheme.bodyMedium!.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.25),
                          ),
                          selectedDecoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          selectedTextStyle: theme.textTheme.bodyMedium!.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          todayDecoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: theme.textTheme.bodyMedium!.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          markersMaxCount: 4,
                          canMarkersOverflow: false,
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, day, events) {
                            if (events.isEmpty) return null;
                            final isSelected = isSameDay(day, _selectedDay);
                            final dotColor = isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.primary;

                            return Positioned(
                              bottom: 6,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: events.take(3).map((_) {
                                  return Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1.2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Selected Day Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                turkishDateFormatted,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedEvents.isEmpty
                                    ? 'Etkinlik bulunmuyor'
                                    : '${selectedEvents.length} Etkinlik planlandı',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selectedEvents.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${selectedEvents.length}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Events List or Empty State
                if (selectedEvents.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.cardBorder(theme.brightness),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.event_available_outlined,
                                size: 36,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Bu tarihte etkinlik yok',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Takvimdeki işaretli günleri seçerek planlanan etkinlikleri inceleyebilirsin.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: _goToNextUpcomingEvent,
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                              label: const Text('Yaklaşan Etkinliğe Git'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final event = selectedEvents[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _CalendarEventCard(
                            event: event,
                            onOpen: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EventDetailsPage(event: event),
                                ),
                              );
                            },
                            onSyncCalendar: () {
                              unawaited(
                                CalendarSyncService.syncEventToCalendar(
                                  context,
                                  event,
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: selectedEvents.length,
                    ),
                  ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
              ],
            ),
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({
    required this.event,
    required this.onOpen,
    required this.onSyncCalendar,
  });

  final PostView event;
  final VoidCallback onOpen;
  final VoidCallback onSyncCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = eventImageUrl(event);
    final date = event.eventDate;
    final timeStr = date != null
        ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : 'Saat belirtilmedi';
    final isPast = date?.isBefore(DateTime.now()) ?? false;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.cardBorder(theme.brightness),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isPast ? 0.02 : 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Small thumbnail area
                    _CalendarEventThumbnail(
                      imageUrl: imageUrl,
                      size: 78,
                    ),
                    const SizedBox(width: 14),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (event.publisher.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                event.publisher,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Text(
                            event.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeStr,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (event.location.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    event.location,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Action Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sync button (active for all events)
                    FilledButton.tonalIcon(
                      onPressed: onSyncCalendar,
                      icon: const Icon(
                        Icons.event_available_rounded,
                        size: 18,
                      ),
                      label: const Text('Takvime Ekle'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Open details
                    TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      label: const Text('Detaylar'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarEventThumbnail extends StatelessWidget {
  const _CalendarEventThumbnail({
    required this.imageUrl,
    this.size = 78.0,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cleanUrl = imageUrl.trim();
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheDimension = (size * pixelRatio).round().clamp(100, 1024).toInt();

    Widget placeholder() {
      return Container(
        width: size,
        height: size,
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.event_note_rounded,
            size: 28,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    Widget content;
    if (cleanUrl.isEmpty) {
      content = placeholder();
    } else if (cleanUrl.startsWith('assets/') || cleanUrl.startsWith('asset:')) {
      final assetPath = cleanUrl.replaceFirst('asset:', '');
      content = Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    } else {
      content = CachedNetworkImage(
        imageUrl: cleanUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: cacheDimension,
        memCacheHeight: cacheDimension,
        maxWidthDiskCache: cacheDimension,
        maxHeightDiskCache: cacheDimension,
        fadeInDuration: const Duration(milliseconds: 180),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 24,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        errorWidget: (context, url, error) => placeholder(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: content,
      ),
    );
  }
}
