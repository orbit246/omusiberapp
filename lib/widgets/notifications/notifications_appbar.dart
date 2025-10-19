import 'package:flutter/material.dart';

class NotificationsAppbar extends StatelessWidget {
  const NotificationsAppbar({super.key});

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
        Text("Bildirimler", style: Theme.of(context).textTheme.headlineMedium),
        Spacer(),
        SizedBox(width: 28),
      ],
    );
  }
}
