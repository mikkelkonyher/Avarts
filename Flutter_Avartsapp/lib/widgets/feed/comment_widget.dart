import 'package:flutter/material.dart';
import 'package:avarts/models/activity_comment.dart';
import 'package:avarts/utils/date_utils.dart' as utils;

class CommentWidget extends StatefulWidget {
  const CommentWidget({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onReact,
    required this.onShowReactionUsers,
    required this.onDelete,
    required this.theme,
    required this.colors,
  });

  final ActivityComment comment;
  final String? currentUserId;
  final void Function(ActivityComment, String) onReply;
  final void Function(ActivityComment, String) onReact;
  final void Function(ActivityComment, String) onShowReactionUsers;
  final void Function(ActivityComment) onDelete;
  final ThemeData theme;
  final ColorScheme colors;

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  bool _repliesExpanded = false;
  bool _isReplying = false;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  bool _isSubmittingReply = false;

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSubmittingReply = true;
    });

    try {
      widget.onReply(widget.comment, content);
      _replyController.clear();
      setState(() {
        _isReplying = false;
        _repliesExpanded = true; // Auto-expand replies to show the new one
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReply = false;
        });
      }
    }
  }

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
                          utils.DateUtils.timeAgo(widget.comment.createdAt),
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
                          onPressed: () {
                            setState(() {
                              _isReplying = !_isReplying;
                              if (_isReplying) {
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () {
                                    if (mounted) {
                                      _replyFocusNode.requestFocus();
                                    }
                                  },
                                );
                              } else {
                                _replyFocusNode.unfocus();
                              }
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
                          child: Text(
                            _isReplying ? 'Cancel' : 'Reply',
                            style: widget.theme.textTheme.bodySmall?.copyWith(
                              color: _isReplying
                                  ? widget.colors.onSurface.withValues(
                                      alpha: 0.6,
                                    )
                                  : widget.colors.primary,
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
          if (_isReplying) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: widget.colors.primary.withValues(
                    alpha: 0.15,
                  ),
                  child: Text(
                    'Me',
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                      color: widget.colors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    focusNode: _replyFocusNode,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: widget.theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Reply to ${widget.comment.author}...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: widget.colors.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _isSubmittingReply ? null : _handleSubmitReply,
                  icon: _isSubmittingReply
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: widget.colors.primary,
                          size: 20,
                        ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
          if (hasReplies && _repliesExpanded) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                children: widget.comment.replies.map((reply) {
                  return CommentWidget(
                    comment: reply,
                    currentUserId: widget.currentUserId,
                    onReply: widget.onReply,
                    onReact: widget.onReact,
                    onShowReactionUsers: widget.onShowReactionUsers,
                    onDelete: widget.onDelete,
                    theme: widget.theme,
                    colors: widget.colors,
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
