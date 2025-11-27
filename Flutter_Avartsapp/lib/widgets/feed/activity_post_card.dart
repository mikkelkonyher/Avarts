import 'package:flutter/material.dart';
import 'package:avarts/models/activity_post.dart';
import 'package:avarts/models/activity_comment.dart';
import 'package:avarts/utils/date_utils.dart' as utils;
import 'package:avarts/widgets/feed/comment_widget.dart';

class ActivityPostCard extends StatefulWidget {
  const ActivityPostCard({
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
    this.shouldExpandComments = false,
    this.showFullDescription = false,
  });

  final ActivityPost post;
  final VoidCallback onGiveKudos;
  final void Function(String) onComment;
  final void Function(ActivityComment, String) onReplyToComment;
  final void Function(ActivityPost, ActivityComment, String) onToggleReaction;
  final void Function(ActivityPost) onShowKudosUsers;
  final void Function(ActivityComment, String) onShowReactionUsers;
  final void Function(ActivityComment) onDeleteComment;
  final String viewerName;
  final String? currentUserId;
  final bool isHighlighted;
  final bool shouldExpandComments;
  final bool showFullDescription;

  @override
  State<ActivityPostCard> createState() => _ActivityPostCardState();
}

class _ActivityPostCardState extends State<ActivityPostCard> {
  bool _commentsExpanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand comments if requested
    if (widget.shouldExpandComments) {
      _commentsExpanded = true;
    }
  }

  @override
  void didUpdateWidget(ActivityPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-expand comments if the flag changed to true
    if (widget.shouldExpandComments && !oldWidget.shouldExpandComments) {
      setState(() {
        _commentsExpanded = true;
      });
    }
  }

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

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      widget.onComment(content);
      _commentController.clear();
      // Keep focus if needed, or unfocus
      _commentFocusNode.unfocus();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final totalCommentCount = _countAllComments(widget.post.comments);

    String description = widget.post.description;
    if (!widget.showFullDescription && description.length > 100) {
      description = '${description.substring(0, 100)}...';
    }

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
                      utils.DateUtils.timeAgo(widget.post.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Chip(
              label: Text(widget.post.activity),
              backgroundColor: colors.primary.withValues(alpha: 0.12),
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
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
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: colors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  utils.DateUtils.formatDuration(widget.post.duration),
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
                  setState(() {
                    if (!_commentsExpanded) {
                      _commentsExpanded = true;
                      // Small delay to allow expansion before focusing
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          _commentFocusNode.requestFocus();
                        }
                      });
                    } else {
                      _commentsExpanded = false;
                      _commentFocusNode.unfocus();
                    }
                  });
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
          if (_commentsExpanded) ...[
            if (widget.post.comments.isNotEmpty) ...[
              const Divider(height: 24),
              ...widget.post.comments.map((comment) {
                return CommentWidget(
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
                );
              }),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.primary.withValues(alpha: 0.15),
                  child: Text(
                    widget.viewerName.characters.first,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSubmitting ? null : _handleSubmitComment,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send_rounded, color: colors.primary),
                ),
              ],
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
              onPressed: () {
                setState(() {
                  _commentsExpanded = true;
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      _commentFocusNode.requestFocus();
                    }
                  });
                });
              },
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
}
