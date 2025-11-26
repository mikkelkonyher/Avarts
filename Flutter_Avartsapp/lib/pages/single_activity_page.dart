import 'package:flutter/material.dart';
import 'package:avarts/models/activity_post.dart';
import 'package:avarts/models/activity_comment.dart';
import 'package:avarts/models/comment_reaction.dart';
import 'package:avarts/services/activity_service.dart';
import 'package:avarts/services/auth_service.dart';
import 'package:avarts/widgets/feed/activity_post_card.dart';
import 'package:avarts/widgets/feed/users_list_bottom_sheet.dart';

class SingleActivityPage extends StatefulWidget {
  const SingleActivityPage({
    super.key,
    required this.activityId,
    required this.loginResult,
  });

  final String activityId;
  final LoginResult loginResult;

  @override
  State<SingleActivityPage> createState() => _SingleActivityPageState();
}

class _SingleActivityPageState extends State<SingleActivityPage> {
  final ActivityService _activityService = ActivityService();
  ActivityPost? _post;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final activity = await _activityService.getActivityWithDetails(
        widget.activityId,
      );

      if (activity == null) {
        setState(() {
          _errorMessage = 'Activity not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        final commentsData = activity['comments'];
        final List<ActivityComment> comments;

        if (commentsData is List) {
          // Helper function to recursively parse comments and their replies
          ActivityComment parseComment(Map<String, dynamic> commentMap) {
            final repliesData = commentMap['replies'] as List? ?? [];
            final replies = repliesData
                .whereType<Map<String, dynamic>>()
                .map<ActivityComment>((reply) => parseComment(reply))
                .toList();

            // Parse reactions
            final reactionsData = commentMap['reactions'] as List? ?? [];
            final reactions = reactionsData
                .whereType<Map<String, dynamic>>()
                .map<CommentReaction>((reaction) {
                  return CommentReaction(
                    id: reaction['id'] as String,
                    userId: reaction['user_id'] as String,
                    emoji: reaction['emoji'] as String,
                    createdAt: DateTime.parse(reaction['created_at'] as String),
                  );
                })
                .toList();

            return ActivityComment(
              id: commentMap['id'] as String,
              userId: commentMap['user_id'] as String,
              author: commentMap['author'] as String,
              content: commentMap['content'] as String,
              createdAt: DateTime.parse(commentMap['created_at'] as String),
              parentCommentId: commentMap['parent_comment_id'] as String?,
              replies: replies,
              reactions: reactions,
            );
          }

          comments = commentsData
              .whereType<Map<String, dynamic>>()
              .map<ActivityComment>((comment) => parseComment(comment))
              .toList();
        } else {
          comments = <ActivityComment>[];
        }

        _post = ActivityPost(
          id: activity['id'] as String,
          author: activity['author_name'] as String? ?? 'User',
          activity: activity['activity'] as String? ?? '',
          title: activity['title'] as String? ?? '',
          description: activity['description'] as String? ?? '',
          duration: Duration(minutes: activity['time_minutes'] as int? ?? 0),
          createdAt: DateTime.parse(activity['created_at'] as String),
          mediaUrl: activity['image_url'] as String?,
          kudos: activity['kudos_count'] as int? ?? 0,
          comments: comments,
          viewerHasKudoed: activity['has_kudoed'] as bool? ?? false,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load activity: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _showKudosUsers(ActivityPost post) async {
    if (post.id == null || post.kudos == 0) return;

    try {
      final users = await _activityService.getKudosUsers(post.id!);
      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return UsersListBottomSheet(
            title: 'Kudos',
            users: users,
            icon: Icons.favorite,
            theme: Theme.of(context),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load kudos: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _giveKudos(ActivityPost post) async {
    if (post.id == null) return;

    // Optimistically update UI
    final wasKudoed = _post!.viewerHasKudoed;

    setState(() {
      if (wasKudoed) {
        // Remove kudo
        _post!.viewerHasKudoed = false;
        _post!.kudos = (_post!.kudos - 1).clamp(0, double.infinity).toInt();
      } else {
        // Add kudo
        _post!.viewerHasKudoed = true;
        _post!.kudos = _post!.kudos + 1;
      }
    });

    try {
      await _activityService.addKudos(post.id!);
    } catch (e) {
      // Revert on error
      setState(() {
        if (wasKudoed) {
          _post!.viewerHasKudoed = true;
          _post!.kudos = _post!.kudos + 1;
        } else {
          _post!.viewerHasKudoed = false;
          _post!.kudos = (_post!.kudos - 1).clamp(0, double.infinity).toInt();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to give kudos: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Helper function to recursively add a reply to a comment
  List<ActivityComment> _addReplyToCommentList(
    List<ActivityComment> comments,
    String parentCommentId,
    ActivityComment newReply,
  ) {
    return comments.map((comment) {
      if (comment.id == parentCommentId) {
        // Found the parent, add reply to its replies list
        final updatedReplies = List<ActivityComment>.from(comment.replies)
          ..add(newReply);
        return ActivityComment(
          id: comment.id,
          userId: comment.userId,
          author: comment.author,
          content: comment.content,
          createdAt: comment.createdAt,
          parentCommentId: comment.parentCommentId,
          replies: updatedReplies,
          reactions: comment.reactions, // Preserve reactions
        );
      } else {
        // Recursively search in replies
        final updatedReplies = _addReplyToCommentList(
          comment.replies,
          parentCommentId,
          newReply,
        );
        return ActivityComment(
          id: comment.id,
          userId: comment.userId,
          author: comment.author,
          content: comment.content,
          createdAt: comment.createdAt,
          parentCommentId: comment.parentCommentId,
          replies: updatedReplies,
          reactions: comment.reactions, // Preserve reactions
        );
      }
    }).toList();
  }

  Future<void> _addComment(ActivityPost post, String content) async {
    if (post.id == null || content.isEmpty) return;

    try {
      final commentResponse = await _activityService.addComment(
        activityId: post.id!,
        content: content,
      );

      // Update local state with the new comment
      setState(() {
        final currentUser = AuthService().currentUser;
        final currentUserId = currentUser?.id;
        final authorName = widget.loginResult.displayName;

        final newComment = ActivityComment(
          id: commentResponse['id'] as String,
          userId: currentUserId ?? '',
          author: authorName,
          content: content,
          createdAt: DateTime.parse(commentResponse['created_at'] as String),
        );

        // Create a new list with the updated comments
        final updatedComments = List<ActivityComment>.from(_post!.comments)
          ..add(newComment);

        // Create a new ActivityPost with updated comments
        _post = ActivityPost(
          id: _post!.id,
          author: _post!.author,
          activity: _post!.activity,
          title: _post!.title,
          description: _post!.description,
          duration: _post!.duration,
          createdAt: _post!.createdAt,
          mediaUrl: _post!.mediaUrl,
          kudos: _post!.kudos,
          comments: updatedComments,
          viewerHasKudoed: _post!.viewerHasKudoed,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _replyToComment(
    ActivityPost post,
    ActivityComment parentComment,
    String content,
  ) async {
    if (post.id == null || content.isEmpty) return;

    try {
      final commentResponse = await _activityService.addComment(
        activityId: post.id!,
        content: content,
        parentCommentId: parentComment.id,
      );

      // Update local state with the new reply
      setState(() {
        final currentUser = AuthService().currentUser;
        final currentUserId = currentUser?.id;
        final authorName = widget.loginResult.displayName;

        final newReply = ActivityComment(
          id: commentResponse['id'] as String,
          userId: currentUserId ?? '',
          author: authorName,
          content: content,
          createdAt: DateTime.parse(commentResponse['created_at'] as String),
          parentCommentId: parentComment.id,
        );

        // Create a new list with the updated comments (recursively add reply)
        final updatedComments = _addReplyToCommentList(
          _post!.comments,
          parentComment.id,
          newReply,
        );

        // Create a new ActivityPost with updated comments
        _post = ActivityPost(
          id: _post!.id,
          author: _post!.author,
          activity: _post!.activity,
          title: _post!.title,
          description: _post!.description,
          duration: _post!.duration,
          createdAt: _post!.createdAt,
          mediaUrl: _post!.mediaUrl,
          kudos: _post!.kudos,
          comments: updatedComments,
          viewerHasKudoed: _post!.viewerHasKudoed,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post reply: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showReactionUsers(ActivityComment comment, String emoji) async {
    try {
      final users = await _activityService.getReactionUsers(
        comment.id,
        emoji: emoji,
      );
      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return UsersListBottomSheet(
            title: '$emoji Reactions',
            users: users,
            icon: null,
            theme: Theme.of(context),
            showEmoji: false,
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reactions: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleReaction(
    ActivityPost post,
    ActivityComment comment,
    String emoji,
  ) async {
    if (post.id == null) return;

    // Optimistically update UI
    setState(() {
      final currentUserId = AuthService().currentUser?.id;
      if (currentUserId == null) return;

      // Helper to recursively find and update ONLY the specific comment
      List<ActivityComment> updateComments(List<ActivityComment> comments) {
        return comments.map((c) {
          if (c.id == comment.id) {
            final hasThisReaction = c.reactions.any(
              (r) => r.userId == currentUserId && r.emoji == emoji,
            );

            final reactionsWithoutUser = c.reactions
                .where((r) => r.userId != currentUserId)
                .toList();

            final updatedReactions = hasThisReaction
                ? reactionsWithoutUser
                : [
                    ...reactionsWithoutUser,
                    CommentReaction(
                      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                      userId: currentUserId,
                      emoji: emoji,
                      createdAt: DateTime.now(),
                    ),
                  ];

            return ActivityComment(
              id: c.id,
              userId: c.userId,
              author: c.author,
              content: c.content,
              createdAt: c.createdAt,
              parentCommentId: c.parentCommentId,
              replies: updateComments(c.replies),
              reactions: updatedReactions,
            );
          } else {
            return ActivityComment(
              id: c.id,
              userId: c.userId,
              author: c.author,
              content: c.content,
              createdAt: c.createdAt,
              parentCommentId: c.parentCommentId,
              replies: updateComments(c.replies),
              reactions: c.reactions,
            );
          }
        }).toList();
      }

      final updatedComments = updateComments(_post!.comments);

      _post = ActivityPost(
        id: _post!.id,
        author: _post!.author,
        activity: _post!.activity,
        title: _post!.title,
        description: _post!.description,
        duration: _post!.duration,
        createdAt: _post!.createdAt,
        mediaUrl: _post!.mediaUrl,
        kudos: _post!.kudos,
        comments: updatedComments,
        viewerHasKudoed: _post!.viewerHasKudoed,
      );
    });

    try {
      await _activityService.toggleCommentReaction(
        commentId: comment.id,
        emoji: emoji,
      );
    } catch (e) {
      // Revert on error by reloading
      await _loadActivity();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to react: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Helper function to recursively remove a comment from the comment tree
  List<ActivityComment> _removeCommentFromList(
    List<ActivityComment> comments,
    String commentId,
  ) {
    return comments.where((c) => c.id != commentId).map((comment) {
      // Recursively remove from replies
      final updatedReplies = _removeCommentFromList(comment.replies, commentId);
      return ActivityComment(
        id: comment.id,
        userId: comment.userId,
        author: comment.author,
        content: comment.content,
        createdAt: comment.createdAt,
        parentCommentId: comment.parentCommentId,
        replies: updatedReplies,
        reactions: comment.reactions, // Preserve reactions
      );
    }).toList();
  }

  Future<void> _deleteComment(
    ActivityPost post,
    ActivityComment comment,
  ) async {
    if (post.id == null) return;

    // Optimistically update UI
    setState(() {
      final updatedComments = _removeCommentFromList(
        _post!.comments,
        comment.id,
      );

      _post = ActivityPost(
        id: _post!.id,
        author: _post!.author,
        activity: _post!.activity,
        title: _post!.title,
        description: _post!.description,
        duration: _post!.duration,
        createdAt: _post!.createdAt,
        mediaUrl: _post!.mediaUrl,
        kudos: _post!.kudos,
        comments: updatedComments,
        viewerHasKudoed: _post!.viewerHasKudoed,
      );
    });

    try {
      await _activityService.deleteComment(comment.id);
    } catch (e) {
      // Revert on error by reloading
      await _loadActivity();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete comment: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _post == null
          ? const Center(child: Text('Activity not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32, top: 16),
              child: ActivityPostCard(
                post: _post!,
                onGiveKudos: () => _giveKudos(_post!),
                onComment: (content) => _addComment(_post!, content),
                onReplyToComment: (comment, content) =>
                    _replyToComment(_post!, comment, content),
                onToggleReaction: (post, comment, emoji) =>
                    _toggleReaction(post, comment, emoji),
                onShowKudosUsers: (post) => _showKudosUsers(post),
                onShowReactionUsers: (comment, emoji) =>
                    _showReactionUsers(comment, emoji),
                onDeleteComment: (comment) => _deleteComment(_post!, comment),
                viewerName: widget.loginResult.displayName,
                currentUserId: AuthService().currentUser?.id,
                shouldExpandComments: true,
                showFullDescription: true,
              ),
            ),
    );
  }
}
