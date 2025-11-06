import 'package:flutter/material.dart';

class SimpleAppbarNoBack extends StatelessWidget {
  final String title;
  const SimpleAppbarNoBack({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 3))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
