import 'package:flutter/material.dart';

class Mainpage extends StatefulWidget {
  const Mainpage({super.key});

  @override
  State<Mainpage> createState() => _MainpageState();
}

class _MainpageState extends State<Mainpage> {
  bool isUpcomingSelected = true;
  int _selectedIndex = 2; // Default to the third item (Etkinlikler)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffDFE1E4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 10),
              child: Text(
                "Etkinlikler",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Divider(
              color: Colors.grey,
              thickness: 1.5,
              indent: 12,
              endIndent: 12,
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildToggleButton(
                  "Yaklaşan Etkinlikler",
                  isUpcomingSelected,
                  true,
                ),
                _buildToggleButton(
                  "Geçmiş Etkinlikler",
                  !isUpcomingSelected,
                  false,
                ),
              ],
            ),
            Spacer(),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Image.asset('assets/no_events.png'),
                    Text(
                      "Henüz Etkinlik Bulunamadı.",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Etkinliklerden haberdar olmak için uygulama bildirimlerini etkinleştirin.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            Spacer(),
            Spacer(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 👈 allows more than 3 items
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Anasayfa"),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: "Mesajlar"),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: "Etkinlikler",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Bildirimler",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isActive, bool isUpcoming) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isUpcomingSelected = isUpcoming;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.32), // shadow color
              blurRadius: 12, // how soft the shadow is
              spreadRadius: 1.4, // how wide the shadow spreads
              offset: const Offset(2, 4), // horizontal and vertical movement
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
