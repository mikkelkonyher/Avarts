import 'package:flutter/material.dart';
import 'package:avarts/utils/date_utils.dart' as utils;

class UsersListBottomSheet extends StatelessWidget {
  const UsersListBottomSheet({
    super.key,
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
                          title: Text(
                            displayName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: createdAt != null
                              ? Text(
                                  utils.DateUtils.timeAgo(
                                    DateTime.parse(createdAt),
                                  ),
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
