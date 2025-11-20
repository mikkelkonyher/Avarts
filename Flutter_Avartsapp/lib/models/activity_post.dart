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
    List<String>? comments,
    this.viewerHasKudoed = false,
    this.id,
  }) : comments = comments ?? <String>[];

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
  final List<String> comments;

  /// Whether the current viewer has given kudos to this post
  bool viewerHasKudoed;
}
