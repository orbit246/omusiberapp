import 'package:omusiber/backend/notifications/simple_push.dart';

final List<SavedNotification> mockNotifications = [
  SavedNotification(
    title: "Yeni Etkinlik: CTF Yarışması",
    body: "OMÜ CTF 2026 için kayıtlar açıldı! Takımını kurmayı unutma.",
    receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
    data: {},
  ),
  SavedNotification(
    title: "Duyuru: Seminer İptali",
    body:
        "Bugün yapılması planlanan 'Ağ Güvenliği' semineri ileri bir tarihe ertelenmiştir.",
    receivedAt: DateTime.now().subtract(const Duration(days: 1)),
    data: {},
  ),
  SavedNotification(
    title: "Üyelik Onayı",
    body:
        "Siber Güvenlik Kulübü üyeliğiniz başarıyla onaylandı. İlk toplantımıza davetlisiniz!",
    receivedAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
    data: {},
  ),
  SavedNotification(
    title: "Bilgilendirme",
    body:
        "Yarın kampüs genelinde ağ bakım çalışması yapılacaktır. İnternet erişiminde kesintiler yaşanabilir.",
    receivedAt: DateTime.now().subtract(const Duration(days: 2)),
    data: {},
  ),
];
