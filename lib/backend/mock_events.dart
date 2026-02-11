import 'package:omusiber/backend/post_view.dart';

final List<PostView> mockEvents = [
  PostView(
    id: "mock_1",
    title: "Siber Güvenlik Farkındalık Haftası",
    description:
        "Siber güvenlik farkındalığını artırmak amacıyla düzenlenecek olan etkinlikler dizisi. seminerler, paneller ve atölyeler içermektedir.",
    tags: ["Farkındalık", "Eğitim", "Seminer"],
    maxContributors: 100,
    remainingContributors: 45,
    ticketPrice: 0,
    location: "Mühendislik Fakültesi Konferans Salonu",
    thubnailUrl:
        "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80",
    imageLinks: [],
    metadata: {
      'datetimeText': "12 Mart 2026",
      'durationText': "3 Gün",
      'ticketText': "Ücretsiz",
    },
  ),
  PostView(
    id: "mock_2",
    title: "Java ile Güvenli Kodlama",
    description:
        "Java programlama dilinde güvenli kod geliştirme teknikleri üzerine yoğunlaştırılmış workshop. Katılımcıların temel düzeyde Java bilmesi beklenmektedir.",
    tags: ["Workshop", "Yazılım", "Java"],
    maxContributors: 30,
    remainingContributors: 5,
    ticketPrice: 0,
    location: "Bilgisayar Lab C Blok",
    thubnailUrl:
        "https://images.unsplash.com/photo-1557683316-973673baf926?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80",
    imageLinks: [],
    metadata: {
      'datetimeText': "20 Mart 2026",
      'durationText': "4 Saat",
      'ticketText': "Kayıt Gerekli",
    },
  ),
  PostView(
    id: "mock_3",
    title: "Ağ Güvenliği 101",
    description:
        "Temel ağ güvenliği kavramları, saldırı türleri ve savunma yöntemleri hakkında giriş seviyesi eğitim.",
    tags: ["Eğitim", "Ağ", "Başlangıç"],
    maxContributors: 50,
    remainingContributors: 50,
    ticketPrice: 0,
    location: "Online (Zoom)",
    thubnailUrl:
        "https://images.unsplash.com/photo-1579546929518-9e396f3cc809?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80",
    imageLinks: [],
    metadata: {
      'datetimeText': "25 Mart 2026",
      'durationText': "2 Saat",
      'ticketText': "Herkes Açık",
    },
  ),
];
