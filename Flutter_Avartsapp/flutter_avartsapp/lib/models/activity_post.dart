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
  }) : comments = comments ?? <String>[];

  final String author;
  final String activity;
  final String title;
  final String description;
  final Duration duration;
  final DateTime createdAt;
  final String? mediaUrl;
  int kudos;
  final List<String> comments;
  bool viewerHasKudoed;
}
