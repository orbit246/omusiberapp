import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omusiber/colors/app_colors.dart';

class ModernExcelTable extends StatefulWidget {
  final List<List<dynamic>> data;
  final String? sheetName;

  const ModernExcelTable({super.key, required this.data, this.sheetName});

  @override
  State<ModernExcelTable> createState() => _ModernExcelTableState();
}

class _ModernExcelTableState extends State<ModernExcelTable> {
  final ScrollController _horizontalController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<List<dynamic>> _filteredData = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _filteredData = widget.data.skip(1).toList();
  }

  @override
  void didUpdateWidget(ModernExcelTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _applyFilter();
    }
  }

  void _applyFilter() {
    final dataRows = widget.data.skip(1).toList();
    if (_searchQuery.isEmpty) {
      _filteredData = dataRows;
    } else {
      _filteredData = dataRows.where((row) {
        return row.any(
          (cell) => cell.toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        );
      }).toList();
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showFullScreenZoom() {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black87,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.1,
                maxScale: 5.0,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(100),
                child: Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.all(16),
                  child: _buildStaticTableContent(context),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticTableContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final headerRow = widget.data.first;
    // Calculate precise width based on content if possible, or fixed
    final double columnWidth = 150.0;

    // Rows to display (filtered)
    final rows = _filteredData;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisSize: MainAxisSize.min,
          children: headerRow.map((cell) {
            return Container(
              width: columnWidth,
              height: 50,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                cell?.toString() ?? "",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
        // Rows
        ...rows.map((row) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: row.map((cell) {
              return Container(
                width: columnWidth,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  cell?.toString() ?? "",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(child: Text("No data found in sheet"));
    }

    final headerRow = widget.data.first;
    // Calculate an approximate width for the table (150px per column min)
    final double columnWidth = 150.0;
    final double tableWidth = headerRow.length * columnWidth;

    return Column(
      children: [
        // Search Bar & Action Buttons
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilter();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search in table...",
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.primary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = "";
                                  _applyFilter();
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Full Screen / Zoom Button
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.fullscreen, color: AppColors.primary),
                  tooltip: "Full Screen Zoom View",
                  onPressed: _showFullScreenZoom,
                ),
              ),
            ],
          ),
        ),

        // Table Area
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.coolGray.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Header Row
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: headerRow.map((cell) {
                            return Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  cell?.toString() ?? "",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Data Rows (Fast ListView)
                      Expanded(
                        child: _filteredData.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: AppColors.coolGray.withOpacity(
                                        0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "No results found",
                                      style: TextStyle(
                                        color: AppColors.coolGray,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredData.length,
                                itemBuilder: (context, index) {
                                  final row = _filteredData[index];
                                  final isAlternate = index % 2 != 0;
                                  return Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isAlternate
                                          ? AppColors.coolGray.withOpacity(0.03)
                                          : Colors.transparent,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.coolGray.withOpacity(
                                            0.05,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap:
                                            () {}, // For hover effect and feedback
                                        child: Row(
                                          children: row.map((cell) {
                                            return Expanded(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                    ),
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  cell?.toString() ?? "",
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
