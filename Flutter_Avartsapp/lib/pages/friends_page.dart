import 'package:flutter/material.dart';
import 'package:flutter_avartsproto/pages/chat_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, required this.currentUser});

  final String currentUser;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _friendHandles = {'lazy_legend'};

  final List<_UserProfile> _allUsers = const [
    _UserProfile(
      displayName: 'Sleepy Sam',
      handle: 'lazy_legend',
      mood: 'Power-napping since 2001',
      avatarColor: Color(0xFF2F81F7),
    ),
    _UserProfile(
      displayName: 'CatVideoCarl',
      handle: 'doom_master',
      mood: '98% cat reels today',
      avatarColor: Color(0xFFD29922),
    ),
    _UserProfile(
      displayName: 'Netflix Nia',
      handle: 'series_sprinter',
      mood: 'Finished 3 series before breakfast',
      avatarColor: Color(0xFF8957E5),
    ),
    _UserProfile(
      displayName: 'Snacky Jack',
      handle: 'chip_connoisseur',
      mood: 'Washed kale with soda',
      avatarColor: Color(0xFFED8B00),
    ),
    _UserProfile(
      displayName: 'Procrastination Pat',
      handle: 'later_gator',
      mood: 'Meetings? Never heard of them',
      avatarColor: Color(0xFF3FB950),
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_UserProfile> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allUsers;
    return _allUsers
        .where(
          (user) =>
              user.displayName.toLowerCase().contains(query) ||
              user.handle.toLowerCase().contains(query),
        )
        .toList();
  }

  void _toggleFriend(_UserProfile profile) {
    setState(() {
      if (_friendHandles.contains(profile.handle)) {
        _friendHandles.remove(profile.handle);
      } else {
        _friendHandles.add(profile.handle);
      }
    });
  }

  void _openChat(_UserProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(friendName: profile.displayName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Friends & Chats')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search lazy athletes...',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                _SectionHeading(
                  title: 'Suggested users',
                  subtitle: 'Tap add to queue them up before the API exists 💪',
                ),
                const SizedBox(height: 12),
                ..._filteredUsers.map((profile) {
                  final isFriend = _friendHandles.contains(profile.handle);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FriendTile(
                      profile: profile,
                      isFriend: isFriend,
                      onChat: () => _openChat(profile),
                      onToggleFriend: () => _toggleFriend(profile),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                _SectionHeading(
                  title: 'Your chill crew',
                  subtitle: _friendHandles.isEmpty
                      ? 'Add someone above to begin chatting'
                      : 'Tap chat to start a convo',
                ),
                const SizedBox(height: 12),
                if (_friendHandles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'No friends yet. We won’t tell anyone.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                else
                  ..._allUsers
                      .where((user) => _friendHandles.contains(user.handle))
                      .map((profile) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _FriendTile(
                            profile: profile,
                            isFriend: true,
                            dense: true,
                            onChat: () => _openChat(profile),
                            onToggleFriend: () => _toggleFriend(profile),
                          ),
                        );
                      }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.profile,
    required this.isFriend,
    required this.onToggleFriend,
    required this.onChat,
    this.dense = false,
  });

  final _UserProfile profile;
  final bool isFriend;
  final VoidCallback onToggleFriend;
  final VoidCallback onChat;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: dense ? 22 : 28,
            backgroundColor: profile.avatarColor.withValues(alpha: 0.18),
            child: Text(
              profile.displayName.characters.first,
              style: theme.textTheme.titleMedium?.copyWith(
                color: profile.avatarColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.displayName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '@${profile.handle}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profile.mood,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: onToggleFriend,
                icon: Icon(isFriend ? Icons.check : Icons.person_add),
                label: Text(isFriend ? 'Added' : 'Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFriend
                      ? colors.primary.withValues(alpha: 0.2)
                      : null,
                  foregroundColor: isFriend ? colors.primary : colors.onPrimary,
                  minimumSize: const Size(0, 36),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isFriend ? onChat : null,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Chat'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _UserProfile {
  const _UserProfile({
    required this.displayName,
    required this.handle,
    required this.mood,
    required this.avatarColor,
  });

  final String displayName;
  final String handle;
  final String mood;
  final Color avatarColor;
}
