import 'package:flutter/material.dart';

class EventDetailsAppbar extends StatelessWidget {
  const EventDetailsAppbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back, size: 28),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        Spacer(),
        Text("Detaylar", style: Theme.of(context).textTheme.headlineMedium),
        Spacer(),
        SizedBox(width: 28),
      ],
    );
  }
}
