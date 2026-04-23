import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class AcademicCalendarPage extends StatefulWidget {
  const AcademicCalendarPage({super.key});

  @override
  State<AcademicCalendarPage> createState() => _AcademicCalendarPageState();
}

class _AcademicCalendarPageState extends State<AcademicCalendarPage> {
  static const String _calendarUrl =
      'https://oidb.omu.edu.tr/tr/ogrenci/akademik-takvimler/2025-2026%20Genel%20Akademik%20Takvim.pdf';
  static const String _cacheFileName = 'academic_calendar.pdf';
  static const String _cacheTimestampKey =
      'academic_calendar_cache_timestamp_ms';
  static const String _cacheSourceUrlKey = 'academic_calendar_cache_source_url';
  static const Duration _cacheDuration = Duration(days: 30);

  late Future<File> _cachedPdfFuture;

  final Map<String, String> _headers = const {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
    'Accept': 'application/pdf,*/*;q=0.8',
  };

  @override
  void initState() {
    super.initState();
    _cachedPdfFuture = _getCachedPdf();
  }

  Future<File> _getCachedPdf({bool forceRefresh = false}) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_cacheFileName');
    final prefs = await SharedPreferences.getInstance();
    final cachedAtMs = prefs.getInt(_cacheTimestampKey);
    final cachedSourceUrl = prefs.getString(_cacheSourceUrlKey);

    final now = DateTime.now();
    final cachedAt = cachedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
    final isCacheFresh =
        !forceRefresh &&
        cachedAt != null &&
        now.difference(cachedAt) < _cacheDuration &&
        cachedSourceUrl == _calendarUrl;

    if (isCacheFresh && await file.exists()) {
      return file;
    }

    try {
      final response = await http
          .get(Uri.parse(_calendarUrl), headers: _headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != HttpStatus.ok || response.bodyBytes.isEmpty) {
        throw HttpException(
          'Academic calendar request failed: ${response.statusCode}',
          uri: Uri.parse(_calendarUrl),
        );
      }

      await file.writeAsBytes(response.bodyBytes, flush: true);
      await prefs.setInt(_cacheTimestampKey, now.millisecondsSinceEpoch);
      await prefs.setString(_cacheSourceUrlKey, _calendarUrl);
      return file;
    } catch (_) {
      if (await file.exists()) {
        return file;
      }
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _cachedPdfFuture = _getCachedPdf(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Akademik Takvim',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _retry,
            tooltip: 'Tekrar dene',
          ),
        ],
      ),
      body: FutureBuilder<File>(
        future: _cachedPdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Akademik takvim yuklenemedi. Lutfen tekrar deneyin.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SfPdfViewer.file(snapshot.data!);
        },
      ),
    );
  }
}
