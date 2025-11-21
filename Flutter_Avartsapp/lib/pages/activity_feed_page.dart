import 'package:flutter/material.dart';
import 'package:avarts/models/activity_post.dart';
import 'package:avarts/pages/myprofile_page.dart';
import 'package:avarts/pages/log_activity_page.dart';
import 'package:avarts/services/auth_service.dart';
import 'package:avarts/services/activity_service.dart';

class ActivityFeedPage extends StatefulWidget {
  const ActivityFeedPage({super.key, required this.loginResult});

  final LoginResult loginResult;

  @override
  State<ActivityFeedPage> createState() => _ActivityFeedPageState();
}

class _ActivityFeedPageState extends State<ActivityFeedPage> {
  final ActivityService _activityService = ActivityService();
  List<ActivityPost> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeed();
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
            comments = commentsData
                .where((comment) => comment is Map<String, dynamic>)
                .map<ActivityComment>((comment) {
                  final commentMap = comment as Map<String, dynamic>;
                  return ActivityComment(
                    id: commentMap['id'] as String,
                    userId: commentMap['user_id'] as String,
                    author: commentMap['author'] as String,
                    content: commentMap['content'] as String,
                    createdAt: DateTime.parse(commentMap['created_at'] as String),
                  );
                })
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
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load feed: ${e.toString()}';
        _isLoading = false;
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity posted successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
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
        updatedPost.kudos = (updatedPost.kudos - 1).clamp(0, double.infinity).toInt();
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
          updatedPost.kudos = (updatedPost.kudos - 1).clamp(0, double.infinity).toInt();
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
              createdAt: DateTime.parse(commentResponse['created_at'] as String),
            );
            
            // Create a new list with the updated comments
            final updatedPost = _posts[index];
            final updatedComments = List<ActivityComment>.from(updatedPost.comments)
              ..add(newComment);
            
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

  Future<void> _deleteComment(ActivityPost post, ActivityComment comment) async {
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
      // Optimistically remove comment from UI
      setState(() {
        final postIndex = _posts.indexWhere((p) => p.id == post.id);
        if (postIndex != -1) {
          final updatedPost = _posts[postIndex];
          final updatedComments = updatedPost.comments
              .where((c) => c.id != comment.id)
              .toList();
          
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _ActivityPostCard(
                              post: post,
                              onGiveKudos: () => _giveKudos(post),
                              onComment: () => _addComment(post),
                              onDeleteComment: (comment) => _deleteComment(post, comment),
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

class _ActivityPostCard extends StatelessWidget {
  const _ActivityPostCard({
    required this.post,
    required this.onGiveKudos,
    required this.onComment,
    required this.onDeleteComment,
    required this.viewerName,
    required this.currentUserId,
  });

  final ActivityPost post;
  final VoidCallback onGiveKudos;
  final VoidCallback onComment;
  final void Function(ActivityComment) onDeleteComment;
  final String viewerName;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        border: Border.all(color: colors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: 0.15),
                child: Text(
                  post.author.characters.first,
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
                    Text(post.author, style: theme.textTheme.titleMedium),
                    Text(
                      _timeAgo(post.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(post.activity),
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (post.mediaUrl != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                post.mediaUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            post.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(post.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: colors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatDuration(post.duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onGiveKudos,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(
                  post.viewerHasKudoed ? Icons.favorite : Icons.favorite_border,
                  color: post.viewerHasKudoed
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.7),
                  size: 18,
                ),
                label: Text('${post.kudos}'),
              ),
              TextButton.icon(
                onPressed: onComment,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text('${post.comments.length}'),
              ),
            ],
          ),
          if (post.comments.isNotEmpty) ...[
            const Divider(height: 24),
            ...post.comments
                .take(2)
                .map(
                  (comment) {
                    final isOwnComment = currentUserId != null && 
                                         comment.userId == currentUserId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${comment.author}: ${comment.content}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isOwnComment)
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: colors.error,
                              onPressed: () => onDeleteComment(comment),
                              tooltip: 'Delete comment',
                            ),
                        ],
                      ),
                    );
                  },
                ),
            if (post.comments.length > 2)
              Text(
                '+${post.comments.length - 2} more comments',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
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
