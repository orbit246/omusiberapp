import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_fonts/google_fonts.dart';

class AcademicCalendarPage extends StatelessWidget {
  const AcademicCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          // Basic info or share if needed
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // We could add share_plus logic here later
            },
          ),
        ],
      ),
      body: SfPdfViewer.network(
        'https://oidb.omu.edu.tr/tr/ogrenci/akademik-takvimler/2025-2026%20Genel%20Akademik%20Takvim.pdf',
        canShowScrollHead: true,
        canShowScrollStatus: true,
        initialZoomLevel: 2.0,
      ),
    );
  }
}
