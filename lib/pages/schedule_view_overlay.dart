import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omusiber/backend/schedule_parser.dart';
import 'package:omusiber/colors/app_colors.dart';

class ScheduleViewOverlay extends StatefulWidget {
  final WeeklySchedule schedule;
  final VoidCallback onClose;

  const ScheduleViewOverlay({
    super.key,
    required this.schedule,
    required this.onClose,
  });

  @override
  State<ScheduleViewOverlay> createState() => _ScheduleViewOverlayState();
}

class _ScheduleViewOverlayState extends State<ScheduleViewOverlay>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          // Content
          Column(
            children: [
              const SizedBox(height: 50),
              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: "1. Sınıf"),
                    Tab(text: "2. Sınıf"),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLessonList(widget.schedule.grade1Lessons),
                    _buildLessonList(widget.schedule.grade2Lessons),
                  ],
                ),
              ),
            ],
          ),

          // Close Button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                shape: const CircleBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonList(List<Lesson> lessons) {
    if (lessons.isEmpty) {
      return Center(
        child: Text(
          "Ders bulunamadı",
          style: GoogleFonts.inter(color: Colors.white70),
        ),
      );
    }

    // Group by Day
    final Map<String, List<Lesson>> grouped = {};
    for (var l in lessons) {
      // Normalize day name if needed, but assuming parser handled it
      if (!grouped.containsKey(l.day)) {
        grouped[l.day] = [];
      }
      grouped[l.day]!.add(l);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dayName = grouped.keys.elementAt(index);
        final dayLessons = grouped[dayName]!;

        return _buildDayCard(dayName, dayLessons);
      },
    );
  }

  Widget _buildDayCard(String day, List<Lesson> lessons) {
    // Only show header if day name is clean
    final displayDay = day.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (displayDay.isEmpty && lessons.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white, // "Image" look: Clean white background
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primary,
            child: Text(
              displayDay,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),

          // Lessons
          ...lessons.map((lesson) {
            return Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Column
                  SizedBox(
                    width: 60,
                    child: Text(
                      lesson.time,
                      style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lesson.room,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
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
}
