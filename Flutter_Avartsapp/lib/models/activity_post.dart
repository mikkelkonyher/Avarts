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

/// Model representing a comment on an activity post
class ActivityComment {
  ActivityComment({
    required this.id,
    required this.userId,
    required this.author,
    required this.content,
    required this.createdAt,
    this.parentCommentId,
    List<ActivityComment>? replies,
    List<CommentReaction>? reactions,
  }) : replies = replies ?? <ActivityComment>[],
       reactions = reactions ?? <CommentReaction>[];

  /// Comment ID from database
  final String id;

  /// User ID of the comment author
  final String userId;

  /// Display name of the comment author
  final String author;

  /// Comment content
  final String content;

  /// When the comment was created
  final DateTime createdAt;

  /// ID of the parent comment if this is a reply (null for top-level comments)
  final String? parentCommentId;

  /// List of replies to this comment
  final List<ActivityComment> replies;

  /// List of reactions to this comment
  final List<CommentReaction> reactions;
}

/// Model representing an activity post in the feed
class ActivityPost {
  ActivityPost({
    required this.author,
    required this.activity,
    required this.title,
    required this.description,
    required this.duration,
    required this.createdAt,
    this.mediaUrl,
    this.kudos = 0,
    List<ActivityComment>? comments,
    this.viewerHasKudoed = false,
    this.id,
  }) : comments = comments ?? <ActivityComment>[];

  /// Optional ID from database (used for updates/deletes)
  final String? id;

  /// Username of the post author
  final String author;

  /// Type of activity (e.g., "Nap on Couch", "Bingewatching classics")
  final String activity;

  /// Post title
  final String title;

  /// Post description/content
  final String description;

  /// Duration of the activity
  final Duration duration;

  /// When the post was created
  final DateTime createdAt;

  /// Optional media/image URL
  final String? mediaUrl;

  /// Number of kudos (likes) the post has received
  int kudos;

  /// List of comments on the post
  final List<ActivityComment> comments;

  /// Whether the current viewer has given kudos to this post
  bool viewerHasKudoed;
}
