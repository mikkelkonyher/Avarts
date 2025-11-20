import 'package:flutter/material.dart';
import 'package:flutter_avartsproto/models/activity_post.dart';
import 'package:flutter_avartsproto/pages/myprofile_page.dart';
import 'package:flutter_avartsproto/pages/log_activity_page.dart';
import 'package:flutter_avartsproto/services/api_service.dart';

class ActivityFeedPage extends StatefulWidget {
  const ActivityFeedPage({super.key, required this.loginResult});

  final LoginResult loginResult;

  @override
  State<ActivityFeedPage> createState() => _ActivityFeedPageState();
}

class _ActivityFeedPageState extends State<ActivityFeedPage> {
  final List<ActivityPost> _posts = [
    ActivityPost(
      author: 'The Dude',
      activity: 'Nap on Couch',
      title: 'Power nap champion',
      description:
          'Managed a 45 min nap between meetings. Feeling refreshed-ish.',
      duration: const Duration(hours: 0, minutes: 45),
      createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
      mediaUrl:
          'https://images.unsplash.com/photo-1518976024611-28bf4b48222e?auto=format&fit=crop&w=800&q=80',
      kudos: 12,
      comments: ['CatVideoCarl: Inspirational stuff', 'Lazy Legend: Goals'],
    ),
    ActivityPost(
      author: 'FatFuck',
      activity: 'Doomscrolling',
      title: 'Important research',
      description: 'Studied 120 new cat memes for science. Zero regrets.',
      duration: const Duration(hours: 2, minutes: 10),
      createdAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 5)),
      mediaUrl:
          'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=800&q=80',
      kudos: 42,
      comments: ['Snacky Jack: Vital contribution to society'],
    ),
    ActivityPost(
      author: 'Naptorius Nate',
      activity: 'Bingewatching classics',
      title: 'Finished another trilogy',
      description: 'All the godfather movies in one sitting. What a journey.',
      duration: const Duration(hours: 9),
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      mediaUrl:
          'https://images.unsplash.com/photo-1461151304267-38535e780c79?auto=format&fit=crop&w=800&q=80',
      kudos: 7,
    ),
  ];

  Future<void> _openLogActivity() async {
    final newPost = await Navigator.of(context).push<ActivityPost>(
      MaterialPageRoute(
        builder: (_) =>
            LogActivityPage(currentUser: widget.loginResult.displayName),
      ),
    );

    if (newPost != null) {
      setState(() {
        _posts.insert(0, newPost);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity posted to your wall!')),
      );
    }
  }

  Future<void> _openInsights() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyProfilePage(loginResult: widget.loginResult),
      ),
    );
  }

  void _giveKudos(ActivityPost post) {
    if (post.viewerHasKudoed) return;
    setState(() {
      post.kudos += 1;
      post.viewerHasKudoed = true;
    });
  }

  Future<void> _addComment(ActivityPost post) async {
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
      setState(() {
        post.comments.add('${widget.loginResult.displayName}: $result');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
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
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        child: ListView.builder(
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
                viewerName: widget.loginResult.displayName,
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
    required this.viewerName,
  });

  final ActivityPost post;
  final VoidCallback onGiveKudos;
  final VoidCallback onComment;
  final String viewerName;

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
                onPressed: post.viewerHasKudoed ? null : onGiveKudos,
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
                  (comment) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      comment,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
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
