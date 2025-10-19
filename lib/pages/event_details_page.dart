import 'package:flutter/material.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/event_details/event_details_appbar.dart';

class EventDetailsPage extends StatelessWidget {
  const EventDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventDetailsAppbar(),
              SizedBox(height: 20),
              Card(
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: Image(image: AssetImage('assets/image.png'), fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      right: 4,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TagChip(tag: EventTag("Ücretsiz", Icons.money_off)),
                          TagChip(tag: EventTag("Siber Güvenlik", Icons.shield, color: Colors.blue)),
                          TagChip(tag: EventTag("Konuklu", Icons.person, color: Colors.orange)),
                          TagChip(tag: EventTag("Android", Icons.android, color: Colors.blueAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Android Development Workshop',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
