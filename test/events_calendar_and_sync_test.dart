import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omusiber/backend/calendar_sync_service.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/pages/new_view/events_calendar_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EventsCalendarPage renders calendar and lists events on day selection', (tester) async {
    final testEvent1 = PostView(
      id: 'event-1',
      title: 'Yapay Zeka Konferansı',
      description: 'Yapay zeka ve gelecek konulu etkinlik',
      tags: ['AI', 'Konferans'],
      maxContributors: 100,
      remainingContributors: 80,
      ticketPrice: 0,
      location: 'Mühendislik Fakültesi',
      thubnailUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe',
      imageLinks: [],
      metadata: {},
      eventDate: DateTime(2026, 10, 20, 14, 0),
    );

    final testEvent2 = PostView(
      id: 'event-2',
      title: 'Siber Güvenlik Çalıştayı',
      description: 'Ağ güvenliği ve etik hackerlık çalıştayı',
      tags: ['Siber', 'Atölye'],
      maxContributors: 50,
      remainingContributors: 20,
      ticketPrice: 0,
      location: 'Uzem Salon 2',
      thubnailUrl: '',
      imageLinks: [],
      metadata: {},
      eventDate: DateTime(2026, 10, 20, 16, 30),
    );

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: EventsCalendarPage(
          initialEvents: [testEvent1, testEvent2],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check title and today button
    expect(find.text('Etkinlik Takvimi'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);

    // Initial selected day should be 20 October 2026 because testEvent1 is on that date
    expect(find.text('Yapay Zeka Konferansı'), findsOneWidget);
    expect(find.text('Siber Güvenlik Çalıştayı'), findsOneWidget);
    expect(find.text('Takvime Ekle'), findsWidgets);

    // Verify small thumbnail area image widget is rendered
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('CalendarSyncService handles event without date gracefully', (tester) async {
    final eventWithoutDate = PostView(
      id: 'event-no-date',
      title: 'Tarihsiz Etkinlik',
      description: 'Tarih henüz netleşmedi',
      tags: [],
      maxContributors: 0,
      remainingContributors: 0,
      ticketPrice: 0,
      location: 'Online',
      thubnailUrl: '',
      imageLinks: [],
      metadata: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  CalendarSyncService.syncEventToCalendar(context, eventWithoutDate);
                },
                child: const Text('Sync'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sync'));
    await tester.pump();

    expect(
      find.text('Bu etkinliğin tarihi belirtilmediği için takvime eklenemiyor.'),
      findsOneWidget,
    );
  });

  testWidgets('CalendarSyncService allows syncing past events', (tester) async {
    const channel = MethodChannel('add_2_calendar');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'add2Cal') {
        return true;
      }
      return null;
    });

    final pastEvent = PostView(
      id: 'event-past',
      title: 'Geçmiş Seminer',
      description: 'Dün tamamlanan etkinlik',
      tags: [],
      maxContributors: 0,
      remainingContributors: 0,
      ticketPrice: 0,
      location: 'Amfi 1',
      thubnailUrl: '',
      imageLinks: [],
      metadata: {},
      eventDate: DateTime.now().subtract(const Duration(days: 3)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  CalendarSyncService.syncEventToCalendar(context, pastEvent);
                },
                child: const Text('Sync Past'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sync Past'));
    await tester.pump();

    expect(
      find.text('Etkinlik takvimine aktarılıyor.'),
      findsOneWidget,
    );
  });

  testWidgets('EventsCalendarPage keeps sync button active for past events', (tester) async {
    final pastDate = DateTime(2025, 5, 10, 10, 0);
    final pastEvent = PostView(
      id: 'past-event-1',
      title: 'Eski Etkinlik',
      description: 'Geçmiş etkinlik',
      tags: [],
      maxContributors: 0,
      remainingContributors: 0,
      ticketPrice: 0,
      location: 'Konferans Salonu',
      thubnailUrl: 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809',
      imageLinks: [],
      metadata: {},
      eventDate: pastDate,
    );

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: EventsCalendarPage(
          initialEvents: [pastEvent],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eski Etkinlik'), findsOneWidget);
    // Button label should show "Takvime Ekle" and remain enabled
    expect(find.text('Takvime Ekle'), findsOneWidget);

    final syncButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Takvime Ekle'),
    );
    expect(syncButton.onPressed, isNotNull);

    // Verify small thumbnail image is present
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}
