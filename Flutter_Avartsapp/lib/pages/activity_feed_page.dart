import 'package:flutter/material.dart';
import 'package:avarts/models/activity_post.dart';
import 'package:avarts/pages/myprofile_page.dart';
import 'package:avarts/pages/log_activity_page.dart';
import 'package:avarts/services/auth_service.dart';
import 'package:avarts/services/activity_service.dart';

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
          return _UsersListBottomSheet(
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

  Future<void> _addComment(ActivityPost post) async {
    if (post.id == null) return;

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave a comment'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'What did you think?'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Post'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      try {
        final commentResponse = await _activityService.addComment(
          activityId: post.id!,
          content: result,
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
              content: result,
              createdAt: DateTime.parse(
                commentResponse['created_at'] as String,
              ),
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
  }

  Future<void> _replyToComment(
    ActivityPost post,
    ActivityComment parentComment,
  ) async {
    if (post.id == null) return;

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reply to ${parentComment.author}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Write a reply...'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Reply'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      try {
        final commentResponse = await _activityService.addComment(
          activityId: post.id!,
          content: result,
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
              content: result,
              createdAt: DateTime.parse(
                commentResponse['created_at'] as String,
              ),
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
          return _UsersListBottomSheet(
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
                    child: _ActivityPostCard(
                      key: ValueKey(post.id),
                      post: post,
                      isHighlighted: isHighlighted,
                      onGiveKudos: () => _giveKudos(post),
                      onComment: () => _addComment(post),
                      onReplyToComment: (comment) =>
                          _replyToComment(post, comment),
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

class _ActivityPostCard extends StatefulWidget {
  const _ActivityPostCard({
    super.key,
    required this.post,
    required this.onGiveKudos,
    required this.onComment,
    required this.onReplyToComment,
    required this.onToggleReaction,
    required this.onShowKudosUsers,
    required this.onShowReactionUsers,
    required this.onDeleteComment,
    required this.viewerName,
    required this.currentUserId,
    this.isHighlighted = false,
  });

  final ActivityPost post;
  final VoidCallback onGiveKudos;
  final VoidCallback onComment;
  final void Function(ActivityComment) onReplyToComment;
  final void Function(ActivityPost, ActivityComment, String) onToggleReaction;
  final void Function(ActivityPost) onShowKudosUsers;
  final void Function(ActivityComment, String) onShowReactionUsers;
  final void Function(ActivityComment) onDeleteComment;
  final String viewerName;
  final String? currentUserId;
  final bool isHighlighted;

  @override
  State<_ActivityPostCard> createState() => _ActivityPostCardState();
}

class _ActivityPostCardState extends State<_ActivityPostCard> {
  bool _commentsExpanded = false;

  int _countAllComments(List<ActivityComment> comments) {
    int count = 0;
    for (final comment in comments) {
      count += 1; // Count the comment itself
      if (comment.replies.isNotEmpty) {
        count += _countAllComments(
          comment.replies,
        ); // Count replies recursively
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final totalCommentCount = _countAllComments(widget.post.comments);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: widget.isHighlighted
            ? colors.primary.withValues(alpha: 0.1)
            : colors.surfaceContainerHighest.withValues(alpha: 0.7),
        border: Border.all(
          color: widget.isHighlighted
              ? colors.primary.withValues(alpha: 0.5)
              : colors.surfaceContainerHighest,
          width: widget.isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: 0.15),
                child: Text(
                  widget.post.author.characters.first,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.author,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      _timeAgo(widget.post.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(widget.post.activity),
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (widget.post.mediaUrl != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                widget.post.mediaUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            widget.post.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(widget.post.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: colors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatDuration(widget.post.duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onGiveKudos,
                onLongPress: widget.post.kudos > 0
                    ? () => widget.onShowKudosUsers(widget.post)
                    : null,
                child: TextButton.icon(
                  onPressed: widget.onGiveKudos,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: Icon(
                    widget.post.viewerHasKudoed
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: widget.post.viewerHasKudoed
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.7),
                    size: 18,
                  ),
                  label: GestureDetector(
                    onTap: widget.post.kudos > 0
                        ? () => widget.onShowKudosUsers(widget.post)
                        : null,
                    child: Text('${widget.post.kudos}'),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  if (widget.post.comments.isNotEmpty) {
                    setState(() {
                      _commentsExpanded = !_commentsExpanded;
                    });
                  } else {
                    widget.onComment();
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(
                  _commentsExpanded
                      ? Icons.chat_bubble
                      : Icons.chat_bubble_outline,
                  size: 18,
                  color: _commentsExpanded
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.7),
                ),
                label: Text('$totalCommentCount'),
              ),
            ],
          ),
          if (_commentsExpanded && widget.post.comments.isNotEmpty) ...[
            const Divider(height: 24),
            ...widget.post.comments.map((comment) {
              return _CommentWidget(
                comment: comment,
                currentUserId: widget.currentUserId,
                onReply: widget.onReplyToComment,
                onReact: (comment, emoji) =>
                    widget.onToggleReaction(widget.post, comment, emoji),
                onShowReactionUsers: (comment, emoji) =>
                    widget.onShowReactionUsers(comment, emoji),
                onDelete: widget.onDeleteComment,
                theme: theme,
                colors: colors,
                timeAgo: _timeAgo,
              );
            }),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onComment,
              icon: const Icon(Icons.add_comment, size: 16),
              label: const Text('Add a comment'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
          if (!_commentsExpanded && widget.post.comments.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _commentsExpanded = true;
                });
              },
              child: Text(
                'View $totalCommentCount ${totalCommentCount == 1 ? 'comment' : 'comments'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
          ],
          if (!_commentsExpanded && widget.post.comments.isEmpty) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: widget.onComment,
              icon: const Icon(Icons.add_comment, size: 16),
              label: const Text('Add a comment'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '$minutes min';
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}

class _CommentWidget extends StatefulWidget {
  const _CommentWidget({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onReact,
    required this.onShowReactionUsers,
    required this.onDelete,
    required this.theme,
    required this.colors,
    required this.timeAgo,
  });

  final ActivityComment comment;
  final String? currentUserId;
  final void Function(ActivityComment) onReply;
  final void Function(ActivityComment, String) onReact;
  final void Function(ActivityComment, String) onShowReactionUsers;
  final void Function(ActivityComment) onDelete;
  final ThemeData theme;
  final ColorScheme colors;
  final String Function(DateTime) timeAgo;

  @override
  State<_CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<_CommentWidget> {
  bool _repliesExpanded = false;

  static const List<String> _availableEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
    '🔥',
    '👏',
    '🎉',
    '💯',
    '😊',
    '🤔',
    '😍',
    '🤯',
    '💪',
    '✨',
  ];

  // Helper to count all replies recursively
  int _countAllReplies(List<ActivityComment> replies) {
    int count = 0;
    for (final reply in replies) {
      count += 1; // Count the reply itself
      if (reply.replies.isNotEmpty) {
        count += _countAllReplies(reply.replies); // Count nested replies
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isOwnComment =
        widget.currentUserId != null &&
        widget.comment.userId == widget.currentUserId;
    final hasReplies = widget.comment.replies.isNotEmpty;
    final replyCount = hasReplies
        ? _countAllReplies(widget.comment.replies)
        : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: widget.colors.primary.withValues(alpha: 0.15),
                child: Text(
                  widget.comment.author.characters.first,
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: widget.colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.comment.author,
                          style: widget.theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: widget.colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.timeAgo(widget.comment.createdAt),
                          style: widget.theme.textTheme.bodySmall?.copyWith(
                            color: widget.colors.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.comment.content,
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        color: widget.colors.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Reactions display
                    if (widget.comment.reactions.isNotEmpty) ...[
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ...widget.comment.reactions
                              .fold<Map<String, int>>(<String, int>{}, (
                                map,
                                r,
                              ) {
                                map[r.emoji] = (map[r.emoji] ?? 0) + 1;
                                return map;
                              })
                              .entries
                              .map((entry) {
                                final hasUserReaction = widget.comment.reactions
                                    .any(
                                      (r) =>
                                          r.emoji == entry.key &&
                                          r.userId == widget.currentUserId,
                                    );
                                return GestureDetector(
                                  onTap: () => widget.onShowReactionUsers(
                                    widget.comment,
                                    entry.key,
                                  ),
                                  onLongPress: () =>
                                      widget.onReact(widget.comment, entry.key),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hasUserReaction
                                          ? widget.colors.primary.withValues(
                                              alpha: 0.15,
                                            )
                                          : widget
                                                .colors
                                                .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: hasUserReaction
                                            ? widget.colors.primary.withValues(
                                                alpha: 0.3,
                                              )
                                            : widget
                                                  .colors
                                                  .surfaceContainerHighest,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${entry.value}',
                                          style: widget
                                              .theme
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: hasUserReaction
                                                    ? widget.colors.primary
                                                    : widget.colors.onSurface
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => widget.onReply(widget.comment),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Reply',
                            style: widget.theme.textTheme.bodySmall?.copyWith(
                              color: widget.colors.primary,
                            ),
                          ),
                        ),
                        if (hasReplies) ...[
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _repliesExpanded = !_repliesExpanded;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _repliesExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 14,
                                  color: widget.colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                                  style: widget.theme.textTheme.bodySmall
                                      ?.copyWith(color: widget.colors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        Builder(
                          builder: (context) {
                            // Find user's current reaction (if any)
                            final userReaction = widget.comment.reactions
                                .where((r) => r.userId == widget.currentUserId)
                                .firstOrNull;

                            return PopupMenuButton<String>(
                              icon: Icon(
                                userReaction != null
                                    ? Icons.sentiment_satisfied
                                    : Icons.add_reaction_outlined,
                                size: 16,
                                color: userReaction != null
                                    ? widget.colors.primary
                                    : widget.colors.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                              tooltip: userReaction != null
                                  ? 'Change reaction (currently ${userReaction.emoji})'
                                  : 'Add reaction',
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              itemBuilder: (context) {
                                return _availableEmojis.map((emoji) {
                                  final isCurrentReaction =
                                      userReaction?.emoji == emoji;
                                  return PopupMenuItem<String>(
                                    value: emoji,
                                    child: Row(
                                      children: [
                                        Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            isCurrentReaction
                                                ? 'Remove'
                                                : 'React',
                                            style: widget
                                                .theme
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                        if (isCurrentReaction)
                                          Icon(
                                            Icons.check,
                                            size: 16,
                                            color: widget.colors.primary,
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              },
                              onSelected: (emoji) =>
                                  widget.onReact(widget.comment, emoji),
                            );
                          },
                        ),
                        if (isOwnComment) ...[
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => widget.onDelete(widget.comment),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Delete',
                              style: widget.theme.textTheme.bodySmall?.copyWith(
                                color: widget.colors.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasReplies && _repliesExpanded) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                children: widget.comment.replies.map((reply) {
                  return _CommentWidget(
                    comment: reply,
                    currentUserId: widget.currentUserId,
                    onReply: widget.onReply,
                    onReact: widget.onReact,
                    onShowReactionUsers: widget.onShowReactionUsers,
                    onDelete: widget.onDelete,
                    theme: widget.theme,
                    colors: widget.colors,
                    timeAgo: widget.timeAgo,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UsersListBottomSheet extends StatelessWidget {
  const _UsersListBottomSheet({
    required this.title,
    required this.users,
    required this.icon,
    required this.theme,
    this.showEmoji = true,
  });

  final String title;
  final List<Map<String, dynamic>> users;
  final IconData? icon;
  final ThemeData theme;
  final bool showEmoji;

  static String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.surfaceContainerHighest,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: colors.primary),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: users.isEmpty
                  ? Center(
                      child: Text(
                        'No users yet',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final displayName =
                            user['display_name'] as String? ?? 'User';
                        final createdAt = user['created_at'] as String?;
                        final emoji = user['emoji'] as String?;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primary.withValues(
                              alpha: 0.15,
                            ),
                            child: Text(
                              displayName.characters.first.toUpperCase(),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(displayName),
                          subtitle: createdAt != null
                              ? Text(
                                  _timeAgo(DateTime.parse(createdAt)),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                )
                              : null,
                          trailing: showEmoji && emoji != null
                              ? Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
