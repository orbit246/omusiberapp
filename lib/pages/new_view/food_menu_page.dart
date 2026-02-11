import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:omusiber/backend/food_menu_service.dart';

class FoodMenuPage extends StatefulWidget {
  const FoodMenuPage({super.key});

  @override
  State<FoodMenuPage> createState() => _FoodMenuPageState();
}

class _FoodMenuPageState extends State<FoodMenuPage> {
  late Future<List<FoodMenu>> _menuFuture;

  @override
  void initState() {
    super.initState();
    _menuFuture = FoodMenuService().fetchMenus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              "Yemek Menüsü",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _menuFuture = FoodMenuService().fetchMenus();
                  });
                },
              ),
            ],
          ),
          FutureBuilder<List<FoodMenu>>(
            future: _menuFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: colorScheme.outline.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Menü bulunamadı.",
                          style: GoogleFonts.inter(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final menus = snapshot.data!;

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final menu = menus[index];
                    return _buildMenuCard(context, menu);
                  }, childCount: menus.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, FoodMenu menu) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isToday = DateUtils.isSameDay(menu.date, DateTime.now());

    final dayFormat = DateFormat('EEEE', 'tr_TR');
    final dateFormat = DateFormat('d MMMM', 'tr_TR');

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isToday
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isToday
              ? colorScheme.primary.withOpacity(0.2)
              : colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayFormat.format(menu.date).toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      dateFormat.format(menu.date),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "BUGÜN",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Food Items
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: menu.items
                  .map((item) => _buildFoodItem(context, item))
                  .toList(),
            ),
          ),

          // Footer / Updated At
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              "Son güncelleme: ${DateFormat('HH:mm').format(menu.updatedAt)}",
              style: GoogleFonts.inter(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(BuildContext context, String item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
