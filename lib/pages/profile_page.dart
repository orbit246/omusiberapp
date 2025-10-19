import 'package:flutter/material.dart';
import 'package:omusiber/pages/updated_page.dart';
import 'package:omusiber/widgets/event_toggle.dart';
import 'package:omusiber/widgets/profile/profile_stat_widget.dart';
import 'package:omusiber/widgets/shared/navbar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  bool _isAnonymous = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: AppNavigationBar(),

      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.arrow_back_ios, size: 28),
                  Spacer(),
                  Text(
                    "Profil",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.settings, size: 28),
                ],
              ),
              SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topCenter,
                          child: Image.asset(
                            "assets/image.png",
                            width: 85,
                            height: 85,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Admin OmuSiber",
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Row(
                            children: [
                              ProfileStatWidget(count: 0, label: "Etkinlik"),
                              ProfileStatWidget(count: 0, label: "Kayıtlı"),
                              ProfileStatWidget(count: 0, label: "Takipçi"),
                            ],
                          ),
                          SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),

              ElevatedButton(
                onPressed: () {},
                style: Theme.of(context).elevatedButtonTheme.style
                    ?.copyWith(
                      minimumSize: MaterialStateProperty.all(
                        const Size.fromHeight(50),
                      ),
                    )
                    .copyWith(elevation: MaterialStateProperty.all(10)),
                child: Row(
                  children: [
                    Icon(
                      Icons.exit_to_app,
                      size: 24,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Çıkış Yap",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 20,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
