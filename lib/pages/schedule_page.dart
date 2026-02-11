import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omusiber/backend/schedule_service.dart';
import 'package:omusiber/backend/view/schedule_model.dart';
import 'package:omusiber/colors/app_colors.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  late Future<List<ProgramSchedule>> _schedulesFuture;
  ProgramSchedule? _selectedProgram;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _schedulesFuture = ScheduleService().fetchSchedules();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _savePreferences();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Ders Programı",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<ProgramSchedule>>(
        future: _schedulesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  Text("Program yüklenemedi", style: GoogleFonts.inter()),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _schedulesFuture = ScheduleService().fetchSchedules();
                      });
                    },
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final schedules = snapshot.data ?? [];
          if (schedules.isEmpty) {
            return const Center(child: Text("Henüz ders programı bulunmuyor."));
          }

          // Sort explicitly by name
          schedules.sort((a, b) => a.programName.compareTo(b.programName));

          // Use first program by default if not selected
          _selectedProgram ??= schedules.first;

          return Column(
            children: [
              // Program Selector (if multiple)
              if (schedules.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ProgramSchedule>(
                        value: _selectedProgram,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: schedules.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(
                              s.programName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedProgram = val;
                            });
                            _savePreferences();
                          }
                        },
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Grade Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.coolGray.withOpacity(0.1),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "1. Sınıf"),
                    Tab(text: "2. Sınıf"),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDayList(_selectedProgram!.grade1),
                    _buildDayList(_selectedProgram!.grade2),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayList(Map<String, List<ScheduleLesson>> daysData) {
    if (daysData.isEmpty) {
      return Center(
        child: Text(
          "Ders bulunamadı",
          style: GoogleFonts.inter(color: Colors.grey),
        ),
      );
    }

    // Sort logic?
    // The map iteration order depends on API response.
    // Usually standard days: Pazartesi, Salı, Çarşamba, Perşembe, Cuma.
    final dayOrder = ['PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA'];
    final sortedKeys = daysData.keys.toList()
      ..sort((a, b) {
        int indexA = dayOrder.indexOf(a.toUpperCase());
        int indexB = dayOrder.indexOf(b.toUpperCase());
        if (indexA == -1) indexA = 99;
        if (indexB == -1) indexB = 99;
        return indexA.compareTo(indexB);
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dayName = sortedKeys[index];
        final lessons = daysData[dayName]!;
        return _buildDayCard(dayName, lessons);
      },
    );
  }

  Widget _buildDayCard(String dayName, List<ScheduleLesson> lessons) {
    if (lessons.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: AppColors.primary,
            child: Text(
              dayName,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // List
          ...lessons.map((lesson) {
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time
                  SizedBox(
                    width: 50,
                    child: Text(
                      lesson.time,
                      style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.courseName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.coolGray,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lesson.classroom,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.coolGray,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _savePreferences() async {
    if (_selectedProgram == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_program_id', _selectedProgram!.id);
      await prefs.setInt('selected_grade_index', _tabController.index);
    } catch (e) {
      debugPrint("Error saving schedule preferences: $e");
    }
  }
}
