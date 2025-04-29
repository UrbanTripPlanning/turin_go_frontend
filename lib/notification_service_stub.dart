class NotificationService {
  static Future<void> initialize() async {}

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {}

  static Future<void> showDelayedNotification({
    required int id,
    required String title,
    required String body,
    int delaySeconds = 5,
  }) async {}
}

