import 'package:flutter/material.dart';

class TestWidgetPage extends StatefulWidget {
  const TestWidgetPage({super.key});

  @override
  State<TestWidgetPage> createState() => _TestWidgetPageState();
}

// TickerProvider is needed by AnimatedSize
class _TestWidgetPageState extends State<TestWidgetPage>
    with TickerProviderStateMixin {
  bool isUpcomingSelected = true;
  int _selectedIndex = 2; // Default to the third item (Etkinlikler)
  bool _expanded = false; // 👈 expansion state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Padding(
                padding: EdgeInsets.only(left: 30, top: 10),
                child: Text(
                  "Etkinlikler",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),

              const Divider(
                color: Colors.grey,
                thickness: 1.5,
                indent: 12,
                endIndent: 12,
              ),

              const SizedBox(height: 12),

              // Toggle buttons
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

              const SizedBox(height: 20),

              // Event card (expandable)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildEventCard(context),
              ),

              // Extra content below to demonstrate push-down
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text("Below content")),
                ),
              ),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  0.32,
                                ), // shadow color
                                blurRadius: 20, // how soft the shadow is
                                offset: const Offset(
                                  1,
                                  3.5,
                                ), // x, y movement of shadow
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              "assets/image.png",
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),
                        Text(
                          "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Divider(color: Colors.grey, thickness: 0.4),
                        Item(
                          icon: Icons.calendar_today,
                          title: "Tarih / Zaman",
                          subtitle: "11:00 AM, Perş 23 Ağustos",
                        ),
                        Divider(color: Colors.grey, thickness: 0.4),
                        Item(
                          icon: Icons.location_on,
                          title: "Lokasyon",
                          subtitle: "Samsun Teknoloji Merkezi, Atakum",
                        ),
                        Divider(color: Colors.grey, thickness: 0.4),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 45,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {},
                                  child: Text("Detaylar"),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.bookmark_outline, size: 28),
                            ),
                            SizedBox(width: 6),
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.share_outlined, size: 28),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom navigation bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
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

  // The expandable card
  Widget _buildEventCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 350), // 👈 smooth + slow
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                direction: Axis.horizontal,
                spacing: 6,
                runSpacing: 6,
                children: [
                  createTag(text: "Ücretsiz", icon: Icons.money_off),
                  createTag(
                    text: "Siber Güvelik",
                    color: Colors.blue,
                    icon: Icons.shield,
                  ),
                  createTag(
                    text: "Konuklu",
                    color: Colors.orange,
                    icon: Icons.person,
                  ),
                  createTag(
                    text: "Son 20 Bilet",
                    color: Colors.purpleAccent,
                    icon: Icons.radio_button_checked_sharp,
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Header row: image + basic info + chevron
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event image (placeholder container here)
                  // Container(
                  //   width: 100,
                  //   height: 100,
                  //   decoration: BoxDecoration(
                  //     color: Colors.grey[400],
                  //     borderRadius: BorderRadius.circular(12),
                  //   ),
                  // For a real image:
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.32), // shadow color
                          blurRadius: 20, // how soft the shadow is
                          offset: const Offset(
                            1,
                            3.5,
                          ), // x, y movement of shadow
                        ),
                      ],
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          "assets/image.png",
                          height: _expanded ? 180 : 90, // 👈 Grow 50%
                          width: _expanded ? 240 : 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Event info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "11:00 AM, Perş 23 Ağustos",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color.fromARGB(255, 53, 53, 54),
                            shadows: [
                              Shadow(
                                color: Colors.black12,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(color: Colors.grey, thickness: 0.6),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Location + chevron (tap area toggles expansion)
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        "Samsun Teknoloji Merkezi, Atakum, Samsun ",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 53, 53, 54),
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0, // 90° when expanded
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: const Icon(
                        Icons.arrow_forward_ios_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // 👇 EXPANDABLE CONTENT
              if (_expanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE6E6E6)),
                const SizedBox(height: 12),

                // More information (anything you want)
                Row(
                  children: const [
                    Icon(Icons.schedule, size: 18, color: Colors.grey),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Süre: 2 saat • 11:00 - 13:00",
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(
                      Icons.confirmation_number_outlined,
                      size: 18,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Bilet: Ücretsiz • Kayıt gerekli",
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(Icons.person, size: 18, color: Colors.grey),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Katılımcı Sayısı: 150",
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline, size: 18, color: Colors.grey),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Açıklama: Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.event_available),
                        label: const Text("Katıl"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                  
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.bookmark_outline, size: 28),
                    ),
                    SizedBox(width: 6),
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.share_outlined, size: 28),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Toggle button builder
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
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.32),
              blurRadius: 12,
              spreadRadius: 1.4,
              offset: const Offset(2, 4),
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

class Item extends StatelessWidget {
  final String title;
  final String subtitle; // Ensure subtitle is non-null
  final IconData icon;

  const Item({
    super.key,
    required this.title,
    this.subtitle = '', // Provide a default value for subtitle
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.black),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
      ],
    );
  }
}

class createTag extends StatelessWidget {
  const createTag({
    super.key,
    required this.text,
    this.color = const Color.fromARGB(255, 106, 187, 108),
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 12,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
