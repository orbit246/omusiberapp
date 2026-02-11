import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omusiber/backend/excel_service.dart';
import 'package:omusiber/widgets/modern_excel_table.dart';
import 'package:omusiber/colors/app_colors.dart';

import 'package:http/http.dart' as http;

import 'package:flutter/services.dart';

class ExcelViewerPage extends StatefulWidget {
  final List<int>? bytes;
  final String? fileUrl;
  final String? title;

  const ExcelViewerPage({super.key, this.bytes, this.fileUrl, this.title});

  @override
  State<ExcelViewerPage> createState() => _ExcelViewerPageState();
}

class _ExcelViewerPageState extends State<ExcelViewerPage> {
  Map<String, List<List<dynamic>>>? _sheetData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Allow landscape for better table viewing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadData();
  }

  @override
  void dispose() {
    // Reset to portrait only when leaving this page
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      List<int>? fileBytes = widget.bytes;

      if (fileBytes == null && widget.fileUrl != null) {
        final response = await http.get(Uri.parse(widget.fileUrl!));
        if (response.statusCode == 200) {
          fileBytes = response.bodyBytes;
        } else {
          throw Exception('Failed to download file: ${response.statusCode}');
        }
      }

      if (fileBytes != null) {
        final data = await ExcelService.parseExcelBytes(fileBytes);
        if (mounted) {
          setState(() {
            _sheetData = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = "No file data or valid URL provided";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Error loading excel: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? "Excel Viewer",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.screen_rotation),
            onPressed: () {
              final isPortrait =
                  MediaQuery.of(context).orientation == Orientation.portrait;
              if (isPortrait) {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);
              } else {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
              }
            },
            tooltip: "Görünümü Döndür",
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              AppColors.primary.withOpacity(0.05),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text("Retry")),
          ],
        ),
      );
    }

    if (_sheetData == null || _sheetData!.isEmpty) {
      return const Center(child: Text("No spreadsheets found"));
    }

    return DefaultTabController(
      length: _sheetData!.keys.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.normal,
            ),
            tabs: _sheetData!.keys.map((name) => Tab(text: name)).toList(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: _sheetData!.entries.map((entry) {
                return ModernExcelTable(
                  data: entry.value,
                  sheetName: entry.key,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
