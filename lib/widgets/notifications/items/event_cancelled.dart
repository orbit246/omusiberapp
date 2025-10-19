import 'package:flutter/material.dart';
import 'package:omusiber/widgets/event_card.dart';

class EventCancelled extends StatelessWidget {
  const EventCancelled({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel, size: 28, color: Colors.red),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Etkinlik İptal Edildi',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 22),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "20 Eylül 2024 - Flutter Geliştirici Konferansı",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Stack(
                children: [Image(image: AssetImage('assets/image.png'), fit: BoxFit.fitWidth)],
              ),
            ),

            SizedBox(height: 10),
            Row(
              spacing: 6,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),

                      elevation: MaterialStateProperty.all<double>(4),
                    ),

                    child: Row(
                      children: [
                        Text('Görüntüle', style: Theme.of(context).textTheme.bodyLarge),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios, size: 20, color: Theme.of(context).colorScheme.onSurface),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
