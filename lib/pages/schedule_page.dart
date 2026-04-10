import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:omusiber/backend/schedule_service.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/schedule_model.dart';
import 'package:omusiber/colors/app_colors.dart';
import 'package:omusiber/pages/new_view/user_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  static const List<_DayColumn> _dayColumns = [
    _DayColumn(key: 'PAZARTESI', label: 'Pazartesi'),
    _DayColumn(key: 'SALI', label: 'Sali'),
    _DayColumn(key: 'CARSAMBA', label: 'Carsamba'),
    _DayColumn(key: 'PERSEMBE', label: 'Persembe'),
    _DayColumn(key: 'CUMA', label: 'Cuma'),
    _DayColumn(key: 'CUMARTESI', label: 'Cumartesi'),
    _DayColumn(key: 'PAZAR', label: 'Pazar'),
  ];

  final ScrollController _horizontalController = ScrollController();
  Timer? _clockTimer;
  late Future<List<ProgramSchedule>> _schedulesFuture;
  final UserProfileService _profileService = UserProfileService();

  ProgramSchedule? _selectedProgram;
  int _selectedGradeIndex = 0;

  @override
  void initState() {
    super.initState();
    _schedulesFuture = _loadSchedules();
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

  Future<List<ProgramSchedule>> _loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final preferredProgramId = prefs.getInt('selected_program_id');
    final preferredGradeIndex = prefs.getInt('selected_grade_index') ?? 0;
    final currentProgramId = _selectedProgram?.id;

    final schedules = await ScheduleService().fetchSchedules();
    schedules.sort((a, b) => a.programName.compareTo(b.programName));

    _selectedGradeIndex = preferredGradeIndex == 1 ? 1 : 0;

    if (schedules.isNotEmpty) {
      final targetId = currentProgramId ?? preferredProgramId;
      ProgramSchedule resolved = schedules.first;

      if (targetId != null) {
        for (final schedule in schedules) {
          if (schedule.id == targetId) {
            resolved = schedule;
            break;
          }
        }
      }

      _selectedProgram = resolved;
      await _savePreferences();
    } else {
      _selectedProgram = null;
    }

    return schedules;
  }

  Future<void> _savePreferences() async {
    final program = _selectedProgram;
    if (program == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_program_id', program.id);
    await prefs.setInt('selected_grade_index', _selectedGradeIndex);
  }

  Future<void> _refreshSchedules() async {
    setState(() {
      _schedulesFuture = _loadSchedules();
    });
  }

  Future<void> _openProfilePage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profilini gormek icin once giris yapmalisin.'),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 10),
        content: Text('Profil yukleniyor...'),
      ),
    );

    final profile = await _profileService.fetchUserProfile(user.uid);

    if (!mounted) return;
    messenger.clearSnackBars();

    if (profile == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profil bilgisi su anda yuklenemedi.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfilePage(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Haftalik Ders Programi',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
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
            return _buildErrorState(context);
          }

          final schedules = snapshot.data ?? [];
          if (schedules.isEmpty) {
            return _buildEmptyState(context);
          }

          final selectedProgram = _resolveSelectedProgram(schedules);
          final gridData = _buildGridData(selectedProgram);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildTodayLessonCard(context, gridData),
              const SizedBox(height: 12),
              _buildProgramSelector(context, schedules),
              const SizedBox(height: 12),
              _buildGradeSwitcher(context),
              const SizedBox(height: 18),
              _buildGridCard(context, gridData),
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
              'Ders programi yuklenemedi',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Merkezi API su an cevap vermiyor olabilir. Baglantiyi kontrol edip tekrar deneyin.',
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
              'Henuz ders programi yok',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'API tarafina program verisi geldikten sonra bu ekran otomatik dolacak.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.coolGray, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  ProgramSchedule _resolveSelectedProgram(List<ProgramSchedule> schedules) {
    final currentId = _selectedProgram?.id;
    ProgramSchedule resolved = schedules.first;

    if (currentId != null) {
      for (final schedule in schedules) {
        if (schedule.id == currentId) {
          resolved = schedule;
          break;
        }
      }
    }

    _selectedProgram = resolved;
    return resolved;
  }

  Widget _buildTodayLessonCard(
    BuildContext context,
    _GridScheduleData gridData,
  ) {
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
                        'Bugun ders yok',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${status.dayLabel} sakin. Takvim bos, minik bir mola fena fikir degil.',
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
                  '${status.dayLabel} icin anlik durum',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cihaz saatine gore guncellenir.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.coolGray,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLessonMomentTile(
                  context,
                  label: 'Simdi',
                  scheduledLesson: status.current,
                  emptyTitle: status.phase == _TodayLessonPhase.beforeFirst
                      ? 'Henuz baslamadi'
                      : 'Gun tamam',
                  emptySubtitle: status.phase == _TodayLessonPhase.beforeFirst
                      ? 'Su an bosluktasin.'
                      : 'Bugunku dersler bitti.',
                ),
                const SizedBox(height: 10),
                _buildLessonMomentTile(
                  context,
                  label: 'Siradaki',
                  scheduledLesson: status.next,
                  emptyTitle: status.phase == _TodayLessonPhase.afterLast
                      ? 'Yeni ders yok'
                      : 'Bekleyen ders yok',
                  emptySubtitle: status.phase == _TodayLessonPhase.afterLast
                      ? 'Takvim bugunluk kapandi.'
                      : 'Sirada yeni bir ders gorunmuyor.',
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


  Widget _buildProgramSelector(
    BuildContext context,
    List<ProgramSchedule> schedules,
  ) {
    final theme = Theme.of(context);
    final selectedProgram = _selectedProgram ?? schedules.first;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sınıfını Seç',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ProgramSchedule>(
                value: selectedProgram,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: schedules.map((schedule) {
                  return DropdownMenuItem<ProgramSchedule>(
                    value: schedule,
                    child: Text(
                      schedule.programName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == null) return;

                  setState(() {
                    _selectedProgram = value;
                  });

                  await _savePreferences();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSwitcher(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(2, (index) {
              final isSelected = index == _selectedGradeIndex;
              final title = index == 0 ? '1. Sinif' : '2. Sinif';

              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    setState(() {
                      _selectedGradeIndex = index;
                    });
                    await _savePreferences();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openProfilePage,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.coolGray.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sinif ve sube bilgisini profilinden degistirebilirsin.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.coolGray,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, _GridScheduleData gridData) {
    final theme = Theme.of(context);
    final visibleDays = gridData.visibleDays;

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
              '${_gradeLabel()} icin ders bulunamadi',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu programin secili yilinda henuz API verisi yok gibi gorunuyor.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.coolGray, height: 1.45),
            ),
          ],
        ),
      );
    }

    const double timeColumnWidth = 88;
    const double dayColumnWidth = 150;
    const double rowHeight = 110;
    const double cellGap = 10;
    final double gridWidth =
        timeColumnWidth +
        (visibleDays.length * dayColumnWidth) +
        ((visibleDays.length + 1) * cellGap);

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
                Text(
                  'Haftalik Grid',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ayni saate denk gelen dersi kendi gununun kutusunda gorursun. Bugun mavi ile vurgulanir.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.coolGray,
                    height: 1.4,
                  ),
                ),
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
              child: SizedBox(
                width: gridWidth,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildCornerHeader(timeColumnWidth, cellGap),
                        ...visibleDays.map((day) {
                          return _buildDayHeader(
                            context,
                            day: day,
                            width: dayColumnWidth,
                            gap: cellGap,
                            isToday: day.key == _todayDayKey(),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...gridData.timeSlots.map((slot) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTimeCell(
                              context,
                              slot: slot,
                              width: timeColumnWidth,
                              height: rowHeight,
                              gap: cellGap,
                            ),
                            ...visibleDays.map((day) {
                              final lesson = gridData
                                  .lessonsByDay[day.key]?[slot.startMinutes];
                              return _buildLessonCell(
                                context,
                                lesson: lesson,
                                width: dayColumnWidth,
                                height: rowHeight,
                                gap: cellGap,
                                isToday: day.key == _todayDayKey(),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerHeader(double width, double gap) {
    return Container(
      width: width,
      height: 74,
      margin: EdgeInsets.only(right: gap),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Saat',
            style: GoogleFonts.inter(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gun',
            style: GoogleFonts.inter(
              color: AppColors.coolGray,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
    required double gap,
    required bool isToday,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      height: 74,
      margin: EdgeInsets.only(right: gap),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            isToday ? 'Bugun' : 'Ders gunu',
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

    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.only(right: gap),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            slot.startLabel,
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            slot.endLabel,
            style: GoogleFonts.inter(
              color: AppColors.coolGray,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCell(
    BuildContext context, {
    required _GridLesson? lesson,
    required double width,
    required double height,
    required double gap,
    required bool isToday,
  }) {
    final theme = Theme.of(context);

    if (lesson == null) {
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
        child: Center(
          child: Text(
            'Bos',
            style: GoogleFonts.inter(
              color: AppColors.coolGray.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.only(right: gap),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: lesson.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              lesson.badge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: lesson.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lesson.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            lesson.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.coolGray,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  _GridScheduleData _buildGridData(ProgramSchedule program) {
    final Map<String, List<ScheduleLesson>> rawData = _selectedGradeIndex == 0
        ? program.grade1
        : program.grade2;

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

    return parts.join(' â€¢ ');
  }

  Color _lessonAccent(ScheduleLesson lesson) {
    const palette = <Color>[
      Color(0xFF2563EB),
      Color(0xFF0D9488),
      Color(0xFF7C3AED),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
      Color(0xFFEF4444),
      Color(0xFF6366F1),
      Color(0xFF14B8A6),
    ];

    final seed =
        '${lesson.courseCode}|${lesson.courseName}|${lesson.classroom}';
    final index = seed.hashCode.abs() % palette.length;
    return palette[index];
  }

  String _gradeLabel() {
    return _selectedGradeIndex == 0 ? '1. Sinif' : '2. Sinif';
  }

  _TodayLessonStatus _resolveTodayLessonStatus(_GridScheduleData gridData) {
    final todayKey = _todayDayKey();
    final dayLabel = _dayLabel(todayKey) ?? 'Bugun';
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

class _GridLesson {
  const _GridLesson({
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String badge;
  final String subtitle;
  final Color accent;
}

class _GridTimeSlot {
  const _GridTimeSlot({
    required this.startMinutes,
    required this.endMinutes,
    required this.startLabel,
    required this.endLabel,
  });

  final int startMinutes;
  final int endMinutes;
  final String startLabel;
  final String endLabel;
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

enum _TodayLessonPhase { noLessons, beforeFirst, inLesson, afterLast }

class _DayColumn {
  const _DayColumn({required this.key, required this.label});

  final String key;
  final String label;
}
