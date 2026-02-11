import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omusiber/widgets/modern_excel_table.dart';
import 'package:omusiber/colors/app_colors.dart';

class ExcelDemoPage extends StatelessWidget {
  const ExcelDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data representing a typical Excel sheet
    final List<List<dynamic>> mockData = [
      [
        'ID',
        'Name',
        'Department',
        'Role',
        'Status',
        'Performance',
        'Join Date',
      ],
      [
        'EP-001',
        'Alex Rivera',
        'Engineering',
        'Lead Architect',
        'Active',
        '98%',
        '2023-01-15',
      ],
      [
        'EP-002',
        'Sarah Chen',
        'Product',
        'Manager',
        'Remote',
        '95%',
        '2023-03-22',
      ],
      [
        'EP-003',
        'Marcus Thorne',
        'Design',
        'UI/UX Lead',
        'Active',
        '92%',
        '2022-11-10',
      ],
      [
        'EP-004',
        'Elena Petrova',
        'Engineering',
        'Senior Dev',
        'On Leave',
        '88%',
        '2023-05-01',
      ],
      [
        'EP-005',
        'James Wilson',
        'Marketing',
        'Analyst',
        'Active',
        '91%',
        '2024-01-08',
      ],
      [
        'EP-006',
        'Sofia Martinez',
        'HR',
        'Specialist',
        'Active',
        '94%',
        '2023-09-14',
      ],
      [
        'EP-007',
        'David Kim',
        'Engineering',
        'Backend Dev',
        'Active',
        '96%',
        '2023-06-30',
      ],
      [
        'EP-008',
        'Lisa Wang',
        'Sales',
        'Strategist',
        'Active',
        '89%',
        '2022-08-12',
      ],
      [
        'EP-009',
        'Ryan Cooper',
        'Product',
        'PO',
        'On Leave',
        '85%',
        '2023-12-19',
      ],
      [
        'EP-010',
        'Amelie Dubois',
        'Engineering',
        'Frontend Dev',
        'Active',
        '97%',
        '2024-02-01',
      ],
      [
        'EP-011',
        'Kevin Heart',
        'Support',
        'Tier 2',
        'Active',
        '90%',
        '2023-04-11',
      ],
      [
        'EP-012',
        'Julia Ray',
        'Design',
        'Illustrator',
        'Remote',
        '93%',
        '2023-07-05',
      ],
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Premium Table Demo",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  "Data Virtualization",
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  "Showing a virtualized list of rows with custom UI",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.coolGray,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ModernExcelTable(
                    data: mockData,
                    sheetName: "Team Directory 2024",
                  ),
                ),
                const SizedBox(height: 20),
                _buildFeatureHighlights(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureHighlights() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _featureIcon(Icons.bolt, "Fast"),
          _featureIcon(Icons.search, "Searchable"),
          _featureIcon(Icons.view_headline, "Virtualized"),
          _featureIcon(Icons.palette, "Premium"),
        ],
      ),
    );
  }

  Widget _featureIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
