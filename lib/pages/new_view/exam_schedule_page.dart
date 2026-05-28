import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:omusiber/backend/exam_schedule_service.dart';
import 'package:omusiber/colors/app_colors.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExamSchedulePage extends StatefulWidget {
  const ExamSchedulePage({super.key});

  @override
  State<ExamSchedulePage> createState() => _ExamSchedulePageState();
}

class _ExamSchedulePageState extends State<ExamSchedulePage> {
  static const String _selectedProgramPrefsKey = 'exam_schedule_selected_program';
  static const String _selectedYearPrefsKey = 'exam_schedule_selected_year';

  final ExamScheduleService _examScheduleService = ExamScheduleService();
  late Future<List<ExamEntry>> _examFuture;
  String? _selectedProgram;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    _examFuture = _examScheduleService.loadExams();
    _restoreSelections();
  }

  Future<void> _refresh() async {
    setState(() {
      _examFuture = _examScheduleService.loadExams();
    });
    await _examFuture;
  }

  Future<void> _restoreSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedProgram = prefs.getString(_selectedProgramPrefsKey);
    final selectedYear = prefs.getInt(_selectedYearPrefsKey);
    if (!mounted) return;

    if (selectedProgram == null && selectedYear == null) {
      return;
    }

    setState(() {
      _selectedProgram = selectedProgram;
      _selectedYear = selectedYear;
    });
  }

  Future<void> _persistSelections() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedProgram == null || _selectedProgram!.isEmpty) {
      await prefs.remove(_selectedProgramPrefsKey);
    } else {
      await prefs.setString(_selectedProgramPrefsKey, _selectedProgram!);
    }

    if (_selectedYear == null) {
      await prefs.remove(_selectedYearPrefsKey);
    } else {
      await prefs.setInt(_selectedYearPrefsKey, _selectedYear!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Sınav Takvimi',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<ExamEntry>>(
        future: _examFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(context);
          }

          if (snapshot.hasError) {
            return _buildErrorState(context);
          }

          final exams = snapshot.data ?? const <ExamEntry>[];
          if (exams.isEmpty) {
            return _buildEmptyState(context);
          }

          final programs =
              exams.map((exam) => exam.programName).toSet().toList()..sort();
          final selectedProgram = programs.contains(_selectedProgram)
              ? _selectedProgram!
              : programs.first;
          final programExams = exams
              .where((exam) => exam.programName == selectedProgram)
              .toList(growable: false);
          final years = programExams.map((exam) => exam.year).toSet().toList()
            ..sort();
          final selectedYear = years.contains(_selectedYear)
              ? _selectedYear!
              : years.first;
          if (_selectedProgram != selectedProgram ||
              _selectedYear != selectedYear) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _selectedProgram = selectedProgram;
                _selectedYear = selectedYear;
              });
              _persistSelections();
            });
          }

          final filteredExams = programExams
              .where((exam) => exam.year == selectedYear)
              .toList(growable: false);
          final nextExam = filteredExams
              .where((exam) => exam.examDate != null)
              .cast<ExamEntry?>()
              .firstWhere(
                (exam) =>
                    exam != null &&
                    !exam.examDate!.isBefore(DateTime.now()),
                orElse: () => null,
              );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildSummaryCard(
                  context,
                  programName: selectedProgram,
                  year: selectedYear,
                  examCount: filteredExams.length,
                  nextExam: nextExam,
                ),
                const SizedBox(height: 18),
                _buildExamListCard(
                  context,
                  allExams: exams,
                  programs: programs,
                  selectedProgram: selectedProgram,
                  years: years,
                  selectedYear: selectedYear,
                  exams: filteredExams,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.coolGray.withValues(alpha: 0.14),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(
                width: 130,
                height: 11,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(height: 8),
              AppSkeleton(
                width: 220,
                height: 18,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(height: 12),
              AppSkeleton(
                height: 54,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.coolGray.withValues(alpha: 0.12),
            ),
          ),
          child: const Column(
            children: [
              AppSkeleton(
                width: 140,
                height: 12,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(height: 12),
              AppSkeleton(
                height: 48,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              SizedBox(height: 16),
              _ExamCardSkeleton(),
              SizedBox(height: 12),
              _ExamCardSkeleton(),
              SizedBox(height: 12),
              _ExamCardSkeleton(),
            ],
          ),
        ),
      ],
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
              'Sınav takvimi yüklenemedi',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bundled sınav dosyası okunurken bir sorun oluştu.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.coolGray, height: 1.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _refresh,
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
              'Henüz sınav verisi yok',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String programName,
    required int year,
    required int examCount,
    required ExamEntry? nextExam,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$programName • $year. sınıf',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.coolGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$examCount sınav tarih sırasına göre listeleniyor',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sıradaki',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nextExam?.courseName ?? 'Yaklaşan sınav görünmüyor',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nextExam == null
                      ? 'Listede geleceğe dönük kayıt bulunamadı.'
                      : _summaryLine(nextExam),
                  style: GoogleFonts.inter(
                    color: AppColors.coolGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _summaryLine(ExamEntry exam) {
    if (exam.isOnline) {
      return '${exam.programName} • Online';
    }

    final parts = <String>[exam.programName];
    if (exam.examDate != null) {
      parts.add(DateFormat('d MMMM yyyy', 'tr_TR').format(exam.examDate!));
    } else if (exam.rawDate.isNotEmpty) {
      parts.add(exam.rawDate);
    }
    if (exam.rawHour.isNotEmpty) {
      parts.add(exam.rawHour);
    }
    return parts.join(' • ');
  }

  Widget _buildExamListCard(
    BuildContext context, {
    required List<ExamEntry> allExams,
    required List<String> programs,
    required String selectedProgram,
    required List<int> years,
    required int selectedYear,
    required List<ExamEntry> exams,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.12)),
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
                  'Tüm sınavlar',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Yıl seçip o sınıfa ait tüm sınavları görebilirsin. Gösterilen bilgiler Çarşamba Ticaret MYO websitesi tarafından sağlanmış olup değişiklik gösterebilir.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.coolGray,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('program-$selectedProgram'),
            initialValue: selectedProgram,
            decoration: InputDecoration(
              labelText: 'Bölüm',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: programs.map((program) {
              return DropdownMenuItem<String>(
                value: program,
                child: Text(program),
              );
            }).toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              final nextYears = allExams
                  .where((exam) => exam.programName == value)
                  .map((exam) => exam.year)
                  .toSet()
                  .toList()
                ..sort();
              setState(() {
                _selectedProgram = value;
                _selectedYear = nextYears.isEmpty ? null : nextYears.first;
              });
              _persistSelections();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('year-$selectedProgram-$selectedYear'),
            initialValue: selectedYear,
            decoration: InputDecoration(
              labelText: 'Sınıf',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: years.map((year) {
              return DropdownMenuItem<int>(
                value: year,
                child: Text('$year. sınıf'),
              );
            }).toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedYear = value);
              _persistSelections();
            },
          ),
          const SizedBox(height: 16),
          ...exams.map((exam) => _buildExamCard(context, exam)),
        ],
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, ExamEntry exam) {
    final theme = Theme.of(context);
    final accent = _accentForExam(exam);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${exam.programName} • ${exam.sectionTitle}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.coolGray,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              exam.courseName,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
                height: 1.2,
              ),
            ),
            if (exam.courseCode.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                exam.courseCode,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (exam.isOnline)
              Text(
                exam.onlineNotice,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.coolGray,
                  height: 1.35,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (exam.examDate != null || exam.rawDate.isNotEmpty)
                    _buildMetaChip(
                      context,
                      icon: Icons.event_rounded,
                      label: exam.examDate != null
                          ? DateFormat(
                              'd MMM yyyy',
                              'tr_TR',
                            ).format(exam.examDate!)
                          : exam.rawDate,
                    ),
                  if (exam.rawHour.isNotEmpty)
                    _buildMetaChip(
                      context,
                      icon: Icons.schedule_rounded,
                      label: exam.rawHour,
                    ),
                  if (exam.displayLocation.isNotEmpty)
                    _buildMetaChip(
                      context,
                      icon: Icons.place_outlined,
                      label: exam.displayLocation,
                    ),
                ],
              ),
            if (exam.studentCount != null || exam.lecturerName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                [
                  if (exam.studentCount != null)
                    'Öğrenci: ${exam.studentCount}',
                  if (exam.lecturerName.isNotEmpty) exam.lecturerName,
                ].join(' • '),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.coolGray,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.coolGray),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _accentForExam(ExamEntry exam) {
    const palette = <Color>[
      Color(0xFF5B7FA3),
      Color(0xFF5D8C85),
      Color(0xFF8A77A8),
      Color(0xFFB48E63),
      Color(0xFFAF7B93),
      Color(0xFF6E93A8),
    ];

    final seed = '${exam.programName}|${exam.courseName}|${exam.courseCode}';
    return palette[seed.hashCode.abs() % palette.length];
  }
}

class _ExamCardSkeleton extends StatelessWidget {
  const _ExamCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.coolGray.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.coolGray.withValues(alpha: 0.12)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(
            width: 170,
            height: 10,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SizedBox(height: 8),
          AppSkeleton(
            width: 220,
            height: 16,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SizedBox(height: 12),
          AppSkeleton(
            height: 28,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          SizedBox(height: 8),
          AppSkeleton(
            width: 190,
            height: 10,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
    );
  }
}
