import 'package:flutter/material.dart';
import 'package:avarts/models/activity_post.dart';
import 'package:avarts/models/activity_comment.dart';
import 'package:avarts/models/comment_reaction.dart';
import 'package:avarts/pages/myprofile_page.dart';
import 'package:avarts/pages/log_activity_page.dart';
import 'package:avarts/services/auth_service.dart';
import 'package:avarts/services/activity_service.dart';
import 'package:avarts/widgets/feed/activity_post_card.dart';
import 'package:avarts/widgets/feed/users_list_bottom_sheet.dart';

class ActivityFeedPage extends StatefulWidget {
  const ActivityFeedPage({
    super.key,
    required this.loginResult,
    this.activityIdToHighlight,
  });

  final LoginResult loginResult;
  final String? activityIdToHighlight;

  @override
  State<ActivityFeedPage> createState() => _ActivityFeedPageState();
}

class _ActivityFeedPageState extends State<ActivityFeedPage> {
  final ActivityService _activityService = ActivityService();
  final ScrollController _scrollController = ScrollController();
  List<ActivityPost> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final activities = await _activityService.getFeedActivities();

      setState(() {
        _posts = activities.map((activity) {
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
                      createdAt: DateTime.parse(
                        reaction['created_at'] as String,
                      ),
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

          return ActivityPost(
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
        }).toList();
        _isLoading = false;
      });

      // Scroll to highlighted activity if specified
      if (widget.activityIdToHighlight != null && _posts.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToActivity(widget.activityIdToHighlight!);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load feed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _scrollToActivity(String activityId) {
    final index = _posts.indexWhere((post) => post.id == activityId);
    if (index != -1 && _scrollController.hasClients) {
      // Calculate approximate position (each post is roughly 400-600px tall)
      final estimatedPosition = index * 500.0;
      _scrollController.animateTo(
        estimatedPosition.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _openLogActivity() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            LogActivityPage(currentUser: widget.loginResult.displayName),
      ),
    );

    if (result == true) {
      // Activity was posted successfully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity posted successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      // Refresh the feed to show the new activity
      await _loadFeed();
    }
  }

  Future<void> _openInsights() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyProfilePage(loginResult: widget.loginResult),
      ),
    );
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
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    final updatedPost = _posts[index];
    final wasKudoed = updatedPost.viewerHasKudoed;

    setState(() {
      if (wasKudoed) {
        // Remove kudo
        updatedPost.viewerHasKudoed = false;
        updatedPost.kudos = (updatedPost.kudos - 1)
            .clamp(0, double.infinity)
            .toInt();
      } else {
        // Add kudo
        updatedPost.viewerHasKudoed = true;
        updatedPost.kudos = updatedPost.kudos + 1;
      }
    });

    try {
      await _activityService.addKudos(post.id!);
    } catch (e) {
      // Revert on error
      setState(() {
        if (wasKudoed) {
          updatedPost.viewerHasKudoed = true;
          updatedPost.kudos = updatedPost.kudos + 1;
        } else {
          updatedPost.viewerHasKudoed = false;
          updatedPost.kudos = (updatedPost.kudos - 1)
              .clamp(0, double.infinity)
              .toInt();
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
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
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
          final updatedPost = _posts[index];
          final updatedComments = List<ActivityComment>.from(
            updatedPost.comments,
          )..add(newComment);

          // Create a new ActivityPost with updated comments
          _posts[index] = ActivityPost(
            id: updatedPost.id,
            author: updatedPost.author,
            activity: updatedPost.activity,
            title: updatedPost.title,
            description: updatedPost.description,
            duration: updatedPost.duration,
            createdAt: updatedPost.createdAt,
            mediaUrl: updatedPost.mediaUrl,
            kudos: updatedPost.kudos,
            comments: updatedComments,
            viewerHasKudoed: updatedPost.viewerHasKudoed,
          );
        }
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
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
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
          final updatedPost = _posts[index];
          final updatedComments = _addReplyToCommentList(
            updatedPost.comments,
            parentComment.id,
            newReply,
          );

          // Create a new ActivityPost with updated comments
          _posts[index] = ActivityPost(
            id: updatedPost.id,
            author: updatedPost.author,
            activity: updatedPost.activity,
            title: updatedPost.title,
            description: updatedPost.description,
            duration: updatedPost.duration,
            createdAt: updatedPost.createdAt,
            mediaUrl: updatedPost.mediaUrl,
            kudos: updatedPost.kudos,
            comments: updatedComments,
            viewerHasKudoed: updatedPost.viewerHasKudoed,
          );
        }
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
      final postIndex = _posts.indexWhere((p) => p.id == post.id);
      if (postIndex != -1) {
        final currentUserId = AuthService().currentUser?.id;
        if (currentUserId == null) return;

        // Helper to recursively find and update ONLY the specific comment
        // Don't modify reactions on other comments
        List<ActivityComment> updateComments(List<ActivityComment> comments) {
          return comments.map((c) {
            if (c.id == comment.id) {
              // This is the comment we want to update
              // Check if user already has this exact reaction
              final hasThisReaction = c.reactions.any(
                (r) => r.userId == currentUserId && r.emoji == emoji,
              );

              // Remove all existing reactions from this user (only one allowed)
              final reactionsWithoutUser = c.reactions
                  .where((r) => r.userId != currentUserId)
                  .toList();

              // If user already has this reaction, remove it (toggle off)
              // Otherwise, add the new reaction (and remove any old one)
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
                replies: updateComments(
                  c.replies,
                ), // Recursively search replies
                reactions: updatedReactions,
              );
            } else {
              // This is not the target comment - keep it as is, but search in replies
              return ActivityComment(
                id: c.id,
                userId: c.userId,
                author: c.author,
                content: c.content,
                createdAt: c.createdAt,
                parentCommentId: c.parentCommentId,
                replies: updateComments(
                  c.replies,
                ), // Recursively search replies
                reactions: c.reactions, // Keep original reactions
              );
            }
          }).toList();
        }

        final updatedPost = _posts[postIndex];
        final updatedComments = updateComments(updatedPost.comments);

        _posts[postIndex] = ActivityPost(
          id: updatedPost.id,
          author: updatedPost.author,
          activity: updatedPost.activity,
          title: updatedPost.title,
          description: updatedPost.description,
          duration: updatedPost.duration,
          createdAt: updatedPost.createdAt,
          mediaUrl: updatedPost.mediaUrl,
          kudos: updatedPost.kudos,
          comments: updatedComments,
          viewerHasKudoed: updatedPost.viewerHasKudoed,
        );
      }
    });

    try {
      await _activityService.toggleCommentReaction(
        commentId: comment.id,
        emoji: emoji,
      );
      // Don't reload - keep the optimistic update to avoid scrolling/closing
    } catch (e) {
      // Revert on error by reloading
      await _loadFeed();
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

  Future<void> _deleteComment(
    ActivityPost post,
    ActivityComment comment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete comment'),
          content: const Text('Are you sure you want to delete this comment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Optimistically remove comment from UI (recursively)
      setState(() {
        final postIndex = _posts.indexWhere((p) => p.id == post.id);
        if (postIndex != -1) {
          final updatedPost = _posts[postIndex];
          final updatedComments = _removeCommentFromList(
            updatedPost.comments,
            comment.id,
          );

          // Create a new ActivityPost with updated comments
          _posts[postIndex] = ActivityPost(
            id: updatedPost.id,
            author: updatedPost.author,
            activity: updatedPost.activity,
            title: updatedPost.title,
            description: updatedPost.description,
            duration: updatedPost.duration,
            createdAt: updatedPost.createdAt,
            mediaUrl: updatedPost.mediaUrl,
            kudos: updatedPost.kudos,
            comments: updatedComments,
            viewerHasKudoed: updatedPost.viewerHasKudoed,
          );
        }
      });

      try {
        await _activityService.deleteComment(comment.id);
      } catch (e) {
        // Revert on error - reload the feed
        await _loadFeed();

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            tooltip: 'View insights',
            icon: const Icon(Icons.insights_rounded),
            onPressed: _openInsights,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLogActivity,
        icon: const Icon(Icons.post_add_rounded),
        label: const Text('Log activity'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFeed,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadFeed,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _posts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.feed_outlined,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No activities yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Be the first to log an activity!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final isHighlighted = post.id == widget.activityIdToHighlight;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ActivityPostCard(
                      key: ValueKey(post.id),
                      post: post,
                      isHighlighted: isHighlighted,
                      onGiveKudos: () => _giveKudos(post),
                      onComment: (content) => _addComment(post, content),
                      onReplyToComment: (comment, content) =>
                          _replyToComment(post, comment, content),
                      onToggleReaction: (post, comment, emoji) =>
                          _toggleReaction(post, comment, emoji),
                      onShowKudosUsers: (post) => _showKudosUsers(post),
                      onShowReactionUsers: (comment, emoji) =>
                          _showReactionUsers(comment, emoji),
                      onDeleteComment: (comment) =>
                          _deleteComment(post, comment),
                      viewerName: widget.loginResult.displayName,
                      currentUserId: AuthService().currentUser?.id,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
