import 'package:flutter/material.dart';

class NoEventsFoundWidget extends StatelessWidget {
  const NoEventsFoundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 32),
          Image.asset('assets/no_events.png'),
          Text("Henüz Etkinlik Bulunamadı.", style: Theme.of(context).textTheme.titleMedium),
          Text(
            "Etkinliklerden haberdar olmak için uygulama bildirimlerini etkinleştirin.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
