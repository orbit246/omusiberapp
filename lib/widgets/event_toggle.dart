import 'package:flutter/material.dart';

class EventToggle extends StatefulWidget {
  const EventToggle({super.key});

  static final selectedIndexNotifier = ValueNotifier<int>(0);

  @override
  State<EventToggle> createState() => _EventToggleState();
}

class _EventToggleState extends State<EventToggle> {
  bool isUpcoming = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 48,
      width: 240,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Stack(
        children: [
          // Moving background highlight
          AnimatedAlign(
            alignment: isUpcoming ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Container(
              width: 116,
              decoration: BoxDecoration(
                color: cs.onSurface, // dark capsule color
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),

          // Options row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => {isUpcoming = true, EventToggle.selectedIndexNotifier.value = 0}),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isUpcoming
                            ? cs
                                  .surface // text color when active
                            : cs.onSurface,
                      ),
                      child: const Text("YENİ"),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => {isUpcoming = false, EventToggle.selectedIndexNotifier.value = 1}),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(fontWeight: FontWeight.w600, color: !isUpcoming ? cs.surface : cs.onSurface),
                      child: const Text("GEÇMİŞ"),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
