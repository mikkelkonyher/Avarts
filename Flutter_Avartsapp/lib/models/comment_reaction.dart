/// Model representing a reaction to a comment
class CommentReaction {
  CommentReaction({
    required this.id,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  /// Reaction ID from database
  final String id;

  /// User ID of the user who reacted
  final String userId;

  /// Emoji string (e.g., '👍', '❤️', '😂')
  final String emoji;

  /// When the reaction was created
  final DateTime createdAt;
}
