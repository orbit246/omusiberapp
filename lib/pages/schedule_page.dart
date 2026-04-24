import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:omusiber/backend/schedule_service.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/academic_faculty_model.dart';
import 'package:omusiber/backend/view/schedule_model.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';
import 'package:omusiber/colors/app_colors.dart';
import 'package:omusiber/pages/new_view/edit_profile_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  static const List<_DayColumn> _dayColumns = [
    _DayColumn(key: 'PAZARTESI', label: 'Pazartesi'),
    _DayColumn(key: 'SALI', label: 'Salı'),
    _DayColumn(key: 'CARSAMBA', label: 'Çarşamba'),
    _DayColumn(key: 'PERSEMBE', label: 'Perşembe'),
    _DayColumn(key: 'CUMA', label: 'Cuma'),
    _DayColumn(key: 'CUMARTESI', label: 'Cumartesi'),
    _DayColumn(key: 'PAZAR', label: 'Pazar'),
  ];

  final ScrollController _horizontalController = ScrollController();
  final UserProfileService _profileService = UserProfileService();
  Timer? _clockTimer;
  late Future<_SchedulePageData> _pageDataFuture;

  ProgramSchedule? _cachedGridProgram;
  String? _cachedGridClassKey;
  _GridScheduleData? _cachedGridData;

  @override
  void initState() {
    super.initState();
    _pageDataFuture = _loadPageData();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<_SchedulePageData> _loadPageData() async {
    final user = FirebaseAuth.instance.currentUser;
    final profile = user == null
        ? UserProfile(uid: '', name: 'Misafir Kullanıcı', role: 'guest')
        : await _profileService.fetchUserProfile(user.uid) ??
              UserProfile(
                uid: user.uid,
                name: user.displayName?.trim().isNotEmpty == true
                    ? user.displayName!.trim()
                    : 'Kullanıcı',
                role: 'member',
              );

    List<AcademicFaculty> faculties;
    try {
      faculties = await _profileService.fetchAcademicFaculties();
    } catch (_) {
      faculties = const <AcademicFaculty>[];
    }

    final resolvedSelection = _resolveAcademicSelection(profile, faculties);
    final schedules = await ScheduleService().fetchSchedules(
      departmentKey: resolvedSelection.department?.key,
    );

    return _SchedulePageData(
      profile: profile,
      faculties: faculties,
      selection: resolvedSelection,
      schedules: schedules,
    );
  }

  Future<void> _refreshSchedules() async {
    setState(() {
      _cachedGridData = null;
      _cachedGridProgram = null;
      _cachedGridClassKey = null;
      _pageDataFuture = _loadPageData();
    });
  }

  Future<void> _openProfilePage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profilini görmek için önce giriş yapmalısın.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => EditProfilePage(uid: user.uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Haftalık Ders Programı',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<_SchedulePageData>(
        future: _pageDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(context);
          }

          final pageData = snapshot.data;
          if (pageData == null) {
            return _buildErrorState(context);
          }

          final selectedProgram = _resolveSelectedProgram(pageData);
          if (selectedProgram == null) {
            return _buildEmptyState(context);
          }

          final selectedClassKey = _resolveSelectedClassKey(
            pageData,
            selectedProgram,
          );
          if (selectedClassKey == null) {
            return _buildEmptyState(context);
          }

          final effectiveSelection = _selectionForProgram(
            pageData.selection,
            selectedProgram,
          );
          final gridData = _gridDataFor(selectedProgram, selectedClassKey);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildTodayLessonCard(
                context,
                gridData,
                schedule: selectedProgram,
                classKey: selectedClassKey,
                classLabel: _classLabelForKey(
                  pageData.faculties,
                  selectedClassKey,
                ),
              ),
              const SizedBox(height: 18),
              _buildGridCard(
                context,
                pageData,
                selectedProgram,
                selectedClassKey,
                effectiveSelection,
                gridData,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.coolGray.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 14),
            Text(
              'Ders programı yüklenemedi',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Merkezi API şu an cevap vermiyor olabilir. Bağlantıyı kontrol edip tekrar deneyin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.coolGray, height: 1.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _refreshSchedules,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 52,
              color: AppColors.coolGray.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 14),
            Text(
              'Henüz ders programı yok',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'API tarafına program verisi geldikten sonra bu ekran otomatik dolacak.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.coolGray, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayLessonCard(
    BuildContext context,
    _GridScheduleData gridData, {
    required ProgramSchedule schedule,
    required String classKey,
    required String classLabel,
  }) {
    final theme = Theme.of(context);
    final status = _resolveTodayLessonStatus(gridData);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.14)),
      ),
      child: status.phase == _TodayLessonPhase.noLessons
          ? Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.free_breakfast_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${schedule.programName} • $classLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.coolGray,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bugün ders yok',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${status.dayLabel} sakin. ${classKey.trim().isEmpty ? "Takvim boş." : "$classLabel için takvim boş."}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.coolGray,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${schedule.programName} • $classLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.coolGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${status.dayLabel} için anlık durum',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLessonMomentTile(
                  context,
                  label: 'Şimdi',
                  scheduledLesson: status.current,
                  emptyTitle: status.phase == _TodayLessonPhase.beforeFirst
                      ? 'Henüz başlamadı'
                      : 'Gün tamam',
                  emptySubtitle: status.phase == _TodayLessonPhase.beforeFirst
                      ? 'Şu an boşluktasın.'
                      : 'Bugünkü dersler bitti.',
                ),
                const SizedBox(height: 10),
                _buildLessonMomentTile(
                  context,
                  label: 'Sıradaki',
                  scheduledLesson: status.next,
                  emptyTitle: status.phase == _TodayLessonPhase.afterLast
                      ? 'Yeni ders yok'
                      : 'Bekleyen ders yok',
                  emptySubtitle: status.phase == _TodayLessonPhase.afterLast
                      ? 'Takvim bugunluk kapandi.'
                      : 'Sırada yeni bir ders görünmüyor.',
                ),
              ],
            ),
    );
  }

  Widget _buildLessonMomentTile(
    BuildContext context, {
    required String label,
    required _ScheduledLesson? scheduledLesson,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    final theme = Theme.of(context);
    final accent = scheduledLesson?.lesson.accent ?? AppColors.coolGray;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: scheduledLesson == null
              ? 0.06
              : theme.brightness == Brightness.dark
              ? 0.22
              : 0.10,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(
            alpha: scheduledLesson == null
                ? 0.16
                : theme.brightness == Brightness.dark
                ? 0.34
                : 0.20,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: scheduledLesson?.lesson.accent ?? AppColors.coolGray,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scheduledLesson?.lesson.title ?? emptyTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            scheduledLesson == null
                ? emptySubtitle
                : '${scheduledLesson.startLabel} - ${scheduledLesson.endLabel} • ${scheduledLesson.lesson.subtitle}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.coolGray,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    _SchedulePageData pageData,
    ProgramSchedule selectedProgram,
    String selectedClassKey,
    _ResolvedAcademicSelection selection,
    _GridScheduleData gridData,
  ) {
    final theme = Theme.of(context);
    final visibleDays = gridData.visibleDays;
    final inferredFallback =
        selectedProgram.academicContext?.isInferredFallback == true;

    if (gridData.timeSlots.isEmpty || gridData.lessonCount == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: AppColors.coolGray.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 12),
            Text(
              'Seçili sınıf için ders bulunamadı',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu programın seçili sınıfı için henüz API verisi görünmüyor.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.coolGray, height: 1.45),
            ),
          ],
        ),
      );
    }

    const double dayHeaderWidth = 108;
    const double timeSlotColumnWidth = 150;
    const double breakColumnWidth = 28;
    const double rowHeight = 98;
    const double headerHeight = 48;
    const double cellGap = 10;
    final todayKey = _todayDayKey();
    final double gridWidth =
        dayHeaderWidth +
        _gridSlotsWidth(
          gridData.timeSlots,
          cellWidth: timeSlotColumnWidth,
          breakWidth: breakColumnWidth,
        ) +
        ((gridData.timeSlots.length + 1) * cellGap);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Haftalık Plan',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedProgram.programName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.coolGray,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _openProfilePage,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Profil',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _scheduleBreadcrumb(selection),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.coolGray,
                    height: 1.4,
                  ),
                ),
                if (inferredFallback) ...[
                  const SizedBox(height: 10),
                  _buildFallbackNote(context),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            radius: const Radius.circular(999),
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: RepaintBoundary(
                child: SizedBox(
                  width: gridWidth,
                  child: Column(
                    children: [
                      RepaintBoundary(
                        child: Row(
                          children: [
                            _buildCornerHeader(
                              dayHeaderWidth,
                              height: headerHeight,
                              gap: cellGap,
                            ),
                            ...gridData.timeSlots.map((slot) {
                              return _buildTimeCell(
                                context,
                                slot: slot,
                                width: _gridSlotWidth(
                                  slot,
                                  cellWidth: timeSlotColumnWidth,
                                  breakWidth: breakColumnWidth,
                                ),
                                height: headerHeight,
                                gap: cellGap,
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...visibleDays.map((day) {
                        final isToday = day.key == todayKey;
                        final row = Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDayHeader(
                              context,
                              day: day,
                              width: dayHeaderWidth,
                              height: rowHeight,
                              gap: cellGap,
                              isToday: isToday,
                            ),
                            ..._buildLessonRowCells(
                              context,
                              day: day,
                              gridData: gridData,
                              cellWidth: timeSlotColumnWidth,
                              breakWidth: breakColumnWidth,
                              cellHeight: rowHeight,
                              gap: cellGap,
                              isToday: isToday,
                            ),
                          ],
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RepaintBoundary(
                            child: isToday
                                ? _TodayScheduleRowHighlight(
                                    width: gridWidth,
                                    height: rowHeight,
                                    child: row,
                                  )
                                : row,
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _scheduleBreadcrumb(_ResolvedAcademicSelection selection) {
    final parts = <String>[
      if (selection.faculty != null) selection.faculty!.name,
      if (selection.department != null) selection.department!.name,
      if (selection.grade != null) selection.grade!.name,
    ];

    if (parts.isEmpty) {
      return 'Akademik seçim bulunamadı';
    }

    return parts.join(' > ');
  }

  ProgramSchedule? _resolveSelectedProgram(_SchedulePageData pageData) {
    if (pageData.schedules.isEmpty) {
      return null;
    }

    for (final schedule in pageData.schedules) {
      if (schedule.academicContext?.hasScheduleMatch == true) {
        return schedule;
      }
    }

    return pageData.schedules.first;
  }

  String? _resolveSelectedClassKey(
    _SchedulePageData pageData,
    ProgramSchedule selectedProgram,
  ) {
    final fallbackSelection = _selectionForProgram(
      pageData.selection,
      selectedProgram,
    );
    final preferredKeys = <String>[
      if (selectedProgram.academicContext?.classKey case final contextClassKey?)
        contextClassKey,
      if (fallbackSelection.grade?.key case final profileGradeKey?)
        profileGradeKey,
      ...selectedProgram.preferredClassKeys,
    ];

    for (final key in preferredKeys) {
      if (selectedProgram.hasLessonsForClassKey(key)) {
        return key;
      }
    }

    for (final key in preferredKeys) {
      if (selectedProgram.hasClassKey(key)) {
        return key;
      }
    }

    final scheduleKeys = selectedProgram.classesByKey.keys;
    return scheduleKeys.isNotEmpty ? scheduleKeys.first : null;
  }

  _ResolvedAcademicSelection _selectionForProgram(
    _ResolvedAcademicSelection profileSelection,
    ProgramSchedule schedule,
  ) {
    final context = schedule.academicContext;
    if (context == null) {
      return profileSelection;
    }

    return _ResolvedAcademicSelection(
      faculty: context.faculty != null
          ? AcademicFaculty(
              key: context.faculty!.key,
              name: context.faculty!.name,
              departments: const <AcademicDepartment>[],
            )
          : profileSelection.faculty,
      department: context.department != null
          ? AcademicDepartment(
              key: context.department!.key,
              name: context.department!.name,
              grades: const <AcademicGrade>[],
            )
          : profileSelection.department,
      grade: context.grade != null
          ? AcademicGrade(
              key: context.grade!.key,
              name: context.grade!.name,
              level: context.grade!.level,
            )
          : profileSelection.grade,
    );
  }

  String _classLabelForKey(List<AcademicFaculty> faculties, String classKey) {
    final normalizedClassKey = classKey.trim();
    if (normalizedClassKey.isEmpty) {
      return 'Sınıf';
    }

    for (final faculty in faculties) {
      for (final department in faculty.departments) {
        for (final grade in department.grades) {
          if (grade.key == normalizedClassKey) {
            return '${department.name} - ${grade.name}';
          }
        }
      }
    }

    final gradeMatch = RegExp(
      r'grade(\d+)$',
      caseSensitive: false,
    ).firstMatch(normalizedClassKey);
    final gradeLevel = int.tryParse(gradeMatch?.group(1) ?? '');
    if (gradeLevel != null) {
      return '$gradeLevel. Sınıf';
    }

    return normalizedClassKey;
  }

  Widget _buildFallbackNote(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Bu program profil bilgilerin eksik olduğu için backend tarafinda tahmini olarak secildi.',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildCornerHeader(
    double width, {
    required double height,
    required double gap,
  }) {
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.only(right: gap),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Gün / Saat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(
    BuildContext context, {
    required _DayColumn day,
    required double width,
    double height = 74,
    required double gap,
    required bool isToday,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.only(right: gap),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.12)
            : theme.colorScheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.coolGray.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.label,
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isToday ? 'Bugün' : 'Ders günü',
            style: GoogleFonts.inter(
              color: isToday ? AppColors.primary : AppColors.coolGray,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCell(
    BuildContext context, {
    required _GridTimeSlot slot,
    required double width,
    required double height,
    required double gap,
  }) {
    final theme = Theme.of(context);

    if (slot.isBreak) {
      return _buildBreakDivider(width: width, height: height, gap: gap);
    }

    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.only(right: gap),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.10)),
      ),
      child: Center(
        child: Text(
          '${slot.startLabel} - ${slot.endLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  double _gridSlotWidth(
    _GridTimeSlot slot, {
    required double cellWidth,
    required double breakWidth,
  }) {
    return slot.isBreak ? breakWidth : cellWidth;
  }

  double _gridSlotsWidth(
    List<_GridTimeSlot> slots, {
    required double cellWidth,
    required double breakWidth,
  }) {
    return slots.fold<double>(
      0,
      (width, slot) =>
          width +
          _gridSlotWidth(slot, cellWidth: cellWidth, breakWidth: breakWidth),
    );
  }

  Widget _buildBreakDivider({
    required double width,
    required double height,
    required double gap,
  }) {
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.only(right: gap),
      child: Center(
        child: CustomPaint(
          size: Size(1.5, height),
          painter: _VerticalDashPainter(
            color: AppColors.coolGray.withValues(alpha: 0.42),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLessonRowCells(
    BuildContext context, {
    required _DayColumn day,
    required _GridScheduleData gridData,
    required double cellWidth,
    required double breakWidth,
    required double cellHeight,
    required double gap,
    required bool isToday,
  }) {
    final cells = <Widget>[];
    final dayLessons = gridData.lessonsByDay[day.key] ?? const {};

    var index = 0;
    while (index < gridData.timeSlots.length) {
      final slot = gridData.timeSlots[index];
      final lesson = dayLessons[slot.startMinutes];

      if (!slot.isBreak && lesson == null) {
        var emptySlotCount = 1;
        while (index + emptySlotCount < gridData.timeSlots.length) {
          final nextSlot = gridData.timeSlots[index + emptySlotCount];
          final nextLesson = dayLessons[nextSlot.startMinutes];
          if (nextSlot.isBreak || nextLesson != null) {
            break;
          }
          emptySlotCount++;
        }

        cells.add(
          _buildEmptyLessonCell(
            context,
            width: (cellWidth * emptySlotCount) + (gap * (emptySlotCount - 1)),
            height: cellHeight,
            gap: gap,
            isToday: isToday,
          ),
        );
        index += emptySlotCount;
        continue;
      }

      cells.add(
        _buildLessonCell(
          context,
          lesson: lesson,
          dayLabel: day.label,
          slot: slot,
          width: _gridSlotWidth(
            slot,
            cellWidth: cellWidth,
            breakWidth: breakWidth,
          ),
          height: cellHeight,
          gap: gap,
          isToday: isToday,
        ),
      );
      index++;
    }

    return cells;
  }

  Widget _buildEmptyLessonCell(
    BuildContext context, {
    required double width,
    required double height,
    required double gap,
    required bool isToday,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.only(right: gap),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.04)
            : theme.colorScheme.surface.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.coolGray.withValues(alpha: 0.08),
        ),
      ),
    );
  }

  Widget _buildLessonCell(
    BuildContext context, {
    required _GridLesson? lesson,
    required String dayLabel,
    required _GridTimeSlot slot,
    required double width,
    required double height,
    required double gap,
    required bool isToday,
  }) {
    final theme = Theme.of(context);

    if (slot.isBreak) {
      return _buildBreakDivider(width: width, height: height, gap: gap);
    }

    if (lesson == null) {
      return _buildEmptyLessonCell(
        context,
        width: width,
        height: height,
        gap: gap,
        isToday: isToday,
      );
    }

    return GestureDetector(
      onTap: () => _showLessonDetailsDialog(
        context,
        lesson: lesson,
        dayLabel: dayLabel,
        slot: slot,
      ),
      child: Container(
        width: width,
        height: height,
        margin: EdgeInsets.only(right: gap),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: lesson.accent.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.24 : 0.12,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: lesson.accent.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.42 : 0.22,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            if (lesson.classroom.isNotEmpty) ...[
              Text(
                lesson.classroom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: lesson.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
            ],
            if (lesson.instructor.isNotEmpty)
              Text(
                lesson.instructor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: GoogleFonts.inter(
                  color: AppColors.coolGray,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLessonDetailsDialog(
    BuildContext context, {
    required _GridLesson lesson,
    required String dayLabel,
    required _GridTimeSlot slot,
  }) {
    final theme = Theme.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: lesson.accent.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: lesson.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              lesson.badge,
                              style: GoogleFonts.inter(
                                color: lesson.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            lesson.title,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: theme.textTheme.titleLarge?.color,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                      splashRadius: 18,
                      tooltip: 'Kapat',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLessonDetailRow(
                  label: 'Gün',
                  value: dayLabel,
                  accent: lesson.accent,
                ),
                const SizedBox(height: 10),
                _buildLessonDetailRow(
                  label: 'Saat',
                  value: '${slot.startLabel} - ${slot.endLabel}',
                  accent: lesson.accent,
                ),
                const SizedBox(height: 10),
                _buildLessonDetailRow(
                  label: 'Ders',
                  value: lesson.title,
                  accent: lesson.accent,
                ),
                if (lesson.courseCode.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildLessonDetailRow(
                    label: 'Kod',
                    value: lesson.courseCode,
                    accent: lesson.accent,
                  ),
                ],
                if (lesson.classroom.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildLessonDetailRow(
                    label: 'Sınıf',
                    value: lesson.classroom,
                    accent: lesson.accent,
                  ),
                ],
                if (lesson.instructor.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildLessonDetailRow(
                    label: 'Hoca',
                    value: lesson.instructor,
                    accent: lesson.accent,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLessonDetailRow({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.coolGray,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  _GridScheduleData _gridDataFor(ProgramSchedule program, String classKey) {
    final cachedGridData = _cachedGridData;
    if (cachedGridData != null &&
        identical(_cachedGridProgram, program) &&
        _cachedGridClassKey == classKey) {
      return cachedGridData;
    }

    final gridData = _buildGridData(program, classKey);
    _cachedGridProgram = program;
    _cachedGridClassKey = classKey;
    _cachedGridData = gridData;
    return gridData;
  }

  _GridScheduleData _buildGridData(ProgramSchedule program, String classKey) {
    final Map<String, List<ScheduleLesson>> rawData = program
        .scheduleForClassKey(classKey);

    final lessonsByDay = <String, Map<int, _GridLesson>>{};
    final uniqueTimes = <int>{};

    for (final day in _dayColumns) {
      lessonsByDay[day.key] = <int, _GridLesson>{};
    }

    rawData.forEach((rawDay, lessons) {
      final normalizedDay = _normalizeDay(rawDay);
      if (normalizedDay == null) return;

      final dayLessons = lessonsByDay[normalizedDay]!;
      for (final lesson in lessons) {
        final startMinutes = _parseMinutes(lesson.time);
        if (startMinutes == null) continue;

        uniqueTimes.add(startMinutes);
        dayLessons[startMinutes] = _GridLesson(
          title: lesson.courseName.trim(),
          badge: _buildLessonBadge(lesson),
          subtitle: _buildLessonSubtitle(lesson),
          courseCode: lesson.courseCode.trim(),
          classroom: lesson.classroom.trim(),
          instructor: lesson.instructor.trim(),
          accent: _lessonAccent(lesson),
        );
      }
    });

    final orderedTimes = uniqueTimes.toList()..sort();
    final timeSlots = orderedTimes.map((minutes) {
      return _GridTimeSlot(
        startMinutes: minutes,
        endMinutes: minutes + 50,
        startLabel: _formatMinutes(minutes),
        endLabel: _formatMinutes(minutes + 50),
      );
    }).toList();

    const lunchStartMinutes = 12 * 60;
    const lunchEndMinutes = 13 * 60;
    final hasMorningLesson = orderedTimes.any(
      (minutes) => minutes < lunchStartMinutes,
    );
    final hasAfternoonLesson = orderedTimes.any(
      (minutes) => minutes >= lunchEndMinutes,
    );

    if (hasMorningLesson && hasAfternoonLesson) {
      timeSlots.add(
        const _GridTimeSlot(
          startMinutes: lunchStartMinutes,
          endMinutes: lunchEndMinutes,
          startLabel: '12:00',
          endLabel: '13:00',
          isBreak: true,
        ),
      );
      timeSlots.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    }

    final visibleDays = _dayColumns.where((day) {
      if (day.key == 'CUMARTESI' || day.key == 'PAZAR') {
        return lessonsByDay[day.key]!.isNotEmpty;
      }
      return true;
    }).toList();

    final lessonCount = lessonsByDay.values.fold<int>(
      0,
      (sum, dayLessons) => sum + dayLessons.length,
    );

    return _GridScheduleData(
      visibleDays: visibleDays,
      timeSlots: timeSlots,
      lessonsByDay: lessonsByDay,
      lessonCount: lessonCount,
    );
  }

  String _buildLessonBadge(ScheduleLesson lesson) {
    final code = lesson.courseCode.trim();
    if (code.isNotEmpty) return code;

    final classroom = lesson.classroom.trim();
    if (classroom.isNotEmpty) return classroom;

    return 'Ders';
  }

  String _buildLessonSubtitle(ScheduleLesson lesson) {
    final parts = <String>[];

    final classroom = lesson.classroom.trim();
    if (classroom.isNotEmpty) {
      parts.add(classroom);
    }

    final instructor = lesson.instructor.trim();
    if (instructor.isNotEmpty) {
      parts.add(instructor);
    }

    if (parts.isEmpty) {
      final code = lesson.courseCode.trim();
      if (code.isNotEmpty) return code;
      return 'Detay yok';
    }

    return parts.join(' / ');
  }

  Color _lessonAccent(ScheduleLesson lesson) {
    const palette = <Color>[
      Color(0xFF5B7FA3),
      Color(0xFF5D8C85),
      Color(0xFF8A77A8),
      Color(0xFFB48E63),
      Color(0xFFAF7B93),
      Color(0xFF6E93A8),
      Color(0xFF6C9A84),
      Color(0xFFB07A73),
      Color(0xFF7886B2),
      Color(0xFF6C9B9B),
    ];

    final seed =
        '${lesson.courseCode}|${lesson.courseName}|${lesson.classroom}';
    final index = seed.hashCode.abs() % palette.length;
    return palette[index];
  }

  _ResolvedAcademicSelection _resolveAcademicSelection(
    UserProfile profile,
    List<AcademicFaculty> faculties,
  ) {
    AcademicFaculty? faculty;
    for (final item in faculties) {
      if (item.key == profile.facultyKey) {
        faculty = item;
        break;
      }
    }

    AcademicDepartment? department;
    if (faculty != null) {
      for (final item in faculty.departments) {
        if (item.key == profile.departmentKey) {
          department = item;
          break;
        }
      }
    }

    AcademicGrade? grade;
    if (department != null) {
      for (final item in department.grades) {
        if (item.key == profile.gradeKey) {
          grade = item;
          break;
        }
      }
    }

    return _ResolvedAcademicSelection(
      faculty: faculty,
      department: department,
      grade: grade,
    );
  }

  _TodayLessonStatus _resolveTodayLessonStatus(_GridScheduleData gridData) {
    final todayKey = _todayDayKey();
    final dayLabel = _dayLabel(todayKey) ?? 'Bugün';
    final todayLessons = _scheduledLessonsForDay(gridData, todayKey);

    if (todayLessons.isEmpty) {
      return _TodayLessonStatus(
        phase: _TodayLessonPhase.noLessons,
        dayLabel: dayLabel,
      );
    }

    final now = DateTime.now();
    final currentMinutes = (now.hour * 60) + now.minute;

    for (var index = 0; index < todayLessons.length; index++) {
      final lesson = todayLessons[index];
      if (currentMinutes >= lesson.startMinutes &&
          currentMinutes < lesson.endMinutes) {
        return _TodayLessonStatus(
          phase: _TodayLessonPhase.inLesson,
          dayLabel: dayLabel,
          current: lesson,
          next: index + 1 < todayLessons.length
              ? todayLessons[index + 1]
              : null,
        );
      }

      if (currentMinutes < lesson.startMinutes) {
        return _TodayLessonStatus(
          phase: _TodayLessonPhase.beforeFirst,
          dayLabel: dayLabel,
          next: lesson,
        );
      }
    }

    return _TodayLessonStatus(
      phase: _TodayLessonPhase.afterLast,
      dayLabel: dayLabel,
    );
  }

  List<_ScheduledLesson> _scheduledLessonsForDay(
    _GridScheduleData gridData,
    String? dayKey,
  ) {
    if (dayKey == null) return const [];

    final lessonsByStart = gridData.lessonsByDay[dayKey];
    if (lessonsByStart == null || lessonsByStart.isEmpty) {
      return const [];
    }

    final endByStart = {
      for (final slot in gridData.timeSlots) slot.startMinutes: slot.endMinutes,
    };

    final lessons = lessonsByStart.entries.map((entry) {
      final startMinutes = entry.key;
      final endMinutes = endByStart[startMinutes] ?? (startMinutes + 50);
      return _ScheduledLesson(
        lesson: entry.value,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      );
    }).toList();

    lessons.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return lessons;
  }

  String? _dayLabel(String? dayKey) {
    if (dayKey == null) return null;

    for (final day in _dayColumns) {
      if (day.key == dayKey) {
        return day.label;
      }
    }

    return null;
  }

  String? _todayDayKey() {
    final weekday = DateTime.now().weekday;
    switch (weekday) {
      case DateTime.monday:
        return 'PAZARTESI';
      case DateTime.tuesday:
        return 'SALI';
      case DateTime.wednesday:
        return 'CARSAMBA';
      case DateTime.thursday:
        return 'PERSEMBE';
      case DateTime.friday:
        return 'CUMA';
      case DateTime.saturday:
        return 'CUMARTESI';
      case DateTime.sunday:
        return 'PAZAR';
      default:
        return null;
    }
  }

  String? _normalizeDay(String value) {
    final normalized = value
        .toUpperCase()
        .replaceAll('Ä°', 'I')
        .replaceAll('I', 'I')
        .replaceAll('Å', 'S')
        .replaceAll('Ã‡', 'C')
        .replaceAll('Ãœ', 'U')
        .replaceAll('Ã–', 'O')
        .replaceAll('Ä', 'G')
        .trim();

    for (final day in _dayColumns) {
      if (normalized == day.key) {
        return day.key;
      }
    }

    return null;
  }

  int? _parseMinutes(String rawTime) {
    final cleaned = rawTime.trim();
    final parts = cleaned.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return (hour * 60) + minute;
  }

  String _formatMinutes(int totalMinutes) {
    final normalized = totalMinutes < 0 ? 0 : totalMinutes;
    final hour = (normalized ~/ 60).toString().padLeft(2, '0');
    final minute = (normalized % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _GridScheduleData {
  const _GridScheduleData({
    required this.visibleDays,
    required this.timeSlots,
    required this.lessonsByDay,
    required this.lessonCount,
  });

  final List<_DayColumn> visibleDays;
  final List<_GridTimeSlot> timeSlots;
  final Map<String, Map<int, _GridLesson>> lessonsByDay;
  final int lessonCount;
}

class _TodayScheduleRowHighlight extends StatelessWidget {
  const _TodayScheduleRowHighlight({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.025),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.34),
                width: 1.4,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _VerticalDashPainter extends CustomPainter {
  const _VerticalDashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashHeight = 7.0;
    const dashGap = 5.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    var startY = 0.0;
    while (startY < size.height) {
      final endY = (startY + dashHeight).clamp(0.0, size.height);
      canvas.drawLine(Offset(centerX, startY), Offset(centerX, endY), paint);
      startY += dashHeight + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalDashPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _GridLesson {
  const _GridLesson({
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.courseCode,
    required this.classroom,
    required this.instructor,
    required this.accent,
  });

  final String title;
  final String badge;
  final String subtitle;
  final String courseCode;
  final String classroom;
  final String instructor;
  final Color accent;
}

class _GridTimeSlot {
  const _GridTimeSlot({
    required this.startMinutes,
    required this.endMinutes,
    required this.startLabel,
    required this.endLabel,
    this.isBreak = false,
  });

  final int startMinutes;
  final int endMinutes;
  final String startLabel;
  final String endLabel;
  final bool isBreak;
}

class _ScheduledLesson {
  const _ScheduledLesson({
    required this.lesson,
    required this.startMinutes,
    required this.endMinutes,
  });

  final _GridLesson lesson;
  final int startMinutes;
  final int endMinutes;

  String get startLabel => _formatClock(startMinutes);
  String get endLabel => _formatClock(endMinutes);

  static String _formatClock(int totalMinutes) {
    final normalized = totalMinutes < 0 ? 0 : totalMinutes;
    final hour = (normalized ~/ 60).toString().padLeft(2, '0');
    final minute = (normalized % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _TodayLessonStatus {
  const _TodayLessonStatus({
    required this.phase,
    required this.dayLabel,
    this.current,
    this.next,
  });

  final _TodayLessonPhase phase;
  final String dayLabel;
  final _ScheduledLesson? current;
  final _ScheduledLesson? next;
}

class _SchedulePageData {
  const _SchedulePageData({
    required this.profile,
    required this.faculties,
    required this.selection,
    this.schedules = const <ProgramSchedule>[],
  });

  final UserProfile profile;
  final List<AcademicFaculty> faculties;
  final _ResolvedAcademicSelection selection;
  final List<ProgramSchedule> schedules;
}

class _ResolvedAcademicSelection {
  const _ResolvedAcademicSelection({this.faculty, this.department, this.grade});

  final AcademicFaculty? faculty;
  final AcademicDepartment? department;
  final AcademicGrade? grade;

  bool get isConfigured =>
      faculty != null &&
      department != null &&
      grade != null &&
      grade!.level != null;
}

enum _TodayLessonPhase { noLessons, beforeFirst, inLesson, afterLast }

class _DayColumn {
  const _DayColumn({required this.key, required this.label});

  final String key;
  final String label;
}
