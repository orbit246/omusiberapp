import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AcademicCalendarPage extends StatefulWidget {
  const AcademicCalendarPage({super.key});

  @override
  State<AcademicCalendarPage> createState() => _AcademicCalendarPageState();
}

class _AcademicCalendarPageState extends State<AcademicCalendarPage> {
  static const String _cacheFileName = 'academic_calendar.jpg';
  static const String _cacheTimestampKey =
      'academic_calendar_cache_timestamp_ms';
  static const String _cacheSourceUrlKey = 'academic_calendar_cache_source_url';
  static const Duration _cacheDuration = Duration(days: 30);

  late Future<File> _cachedImageFuture;

  final Map<String, String> _headers = const {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  @override
  void initState() {
    super.initState();
    _cachedImageFuture = _getCachedImage();
  }

  List<String> _calendarCandidates() {
    final now = DateTime.now();
    final currentAcademicStartYear = now.month >= 9 ? now.year : now.year - 1;
    final candidateStartYears = <int>{
      currentAcademicStartYear,
      currentAcademicStartYear - 1,
      currentAcademicStartYear + 1,
    };

    return candidateStartYears
        .map((startYear) {
          final endYear = startYear + 1;
          final fileName = '$startYear-$endYear Genel Akademik Takvim.jpg';
          return Uri.encodeFull(
            'https://oidb.omu.edu.tr/tr/ogrenci/akademik-takvimler/$fileName',
          );
        })
        .toList(growable: false);
  }

  Future<File> _getCachedImage({bool forceRefresh = false}) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_cacheFileName');
    final prefs = await SharedPreferences.getInstance();
    final cachedAtMs = prefs.getInt(_cacheTimestampKey);
    final cachedSourceUrl = prefs.getString(_cacheSourceUrlKey);

    final now = DateTime.now();
    final cachedAt = cachedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
    final candidateUrls = _calendarCandidates();
    final isCacheFresh =
        !forceRefresh &&
        cachedAt != null &&
        now.difference(cachedAt) < _cacheDuration &&
        cachedSourceUrl != null &&
        candidateUrls.contains(cachedSourceUrl);

    if (isCacheFresh && await file.exists()) {
      return file;
    }

    Object? lastError;
    for (final url in candidateUrls) {
      try {
        final response = await http
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != HttpStatus.ok ||
            response.bodyBytes.isEmpty) {
          lastError = HttpException(
            'Academic calendar request failed: ${response.statusCode}',
            uri: Uri.parse(url),
          );
          continue;
        }

        await file.writeAsBytes(response.bodyBytes, flush: true);
        await prefs.setInt(_cacheTimestampKey, now.millisecondsSinceEpoch);
        await prefs.setString(_cacheSourceUrlKey, url);
        return file;
      } catch (error) {
        lastError = error;
      }
    }

    if (await file.exists()) {
      return file;
    }

    throw lastError ??
        const HttpException('Academic calendar image could not be downloaded.');
  }

  void _retry() {
    setState(() {
      _cachedImageFuture = _getCachedImage(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Akademik Takvim",
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
        future: _cachedImageFuture,
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

          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image.file(
                snapshot.data!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Akademik takvim gorseli acilamadi.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
