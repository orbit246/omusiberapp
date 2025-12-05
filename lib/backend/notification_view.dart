enum NotifcationType {
  eventPublished,
  warning,
  error,
}

class NotificationView {
  final NotifcationType type;
  final String title;
  final String message;

  NotificationView({
    required this.type,
    required this.title,
    required this.message,
  });
}