import 'dart:async';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/deep_link_service.dart';
import 'package:omusiber/backend/post_view.dart';

class CalendarSyncService {
  CalendarSyncService._();

  /// Syncs / adds an individual [PostView] event to the user's native device calendar
  /// (works on both iOS and Android).
  static Future<bool> syncEventToCalendar(
    BuildContext context,
    PostView event,
  ) async {
    final eventDate = event.eventDate;
    if (eventDate == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu etkinliğin tarihi belirtilmediği için takvime eklenemiyor.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final startDate = eventDate;
    final endDate = _computeEndDate(startDate, event);
    final isAllDay = (startDate.hour == 0 && startDate.minute == 0);

    final eventUrl =
        (event.registrationUrl != null &&
                event.registrationUrl!.trim().isNotEmpty)
            ? event.registrationUrl!.trim()
            : (event.id.isNotEmpty
                ? AkademizDeepLink.eventUri(event.id).toString()
                : null);

    final calendarEvent = Event(
      title: event.title,
      description: event.description.isNotEmpty ? event.description : null,
      location: event.location.isNotEmpty ? event.location : null,
      startDate: startDate,
      endDate: endDate,
      allDay: isAllDay,
      iosParams: IOSParams(
        reminder: const Duration(minutes: 60),
        url: eventUrl,
      ),
      androidParams: const AndroidParams(),
    );

    try {
      final success = await Add2Calendar.addEvent2Cal(calendarEvent);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    success
                        ? 'Etkinlik takvimine aktarılıyor.'
                        : 'Takvim uygulaması açılamadı.',
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return success;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Takvime eklenirken bir sorun oluştu: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  static DateTime _computeEndDate(DateTime start, PostView event) {
    final rawDuration = event.metadata['durationText']?.toString() ?? '';
    final match = RegExp(r'(\d+)\s*saat', caseSensitive: false).firstMatch(rawDuration);
    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '2') ?? 2;
      return start.add(Duration(hours: hours));
    }
    return start.add(const Duration(hours: 2));
  }
}
