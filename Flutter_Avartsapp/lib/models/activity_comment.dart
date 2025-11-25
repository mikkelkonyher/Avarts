import 'package:avarts/models/comment_reaction.dart';

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
