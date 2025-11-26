enum NotificationType { kudo, comment, reply, reaction, follow }

class NotificationItem {
  final String id;
  final NotificationType type;
  final String actorId;
  final String actorName;
  final String activityId;
  final String? activityTitle;
  final String? commentId;
  final DateTime createdAt;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.activityId,
    this.activityTitle,
    this.commentId,
    required this.createdAt,
    this.isRead = false,
  });
}
