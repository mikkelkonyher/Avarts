import 'package:flutter/material.dart';
import 'package:avarts/models/user_profile.dart';
import 'package:avarts/pages/chat_page.dart';
import 'package:avarts/services/user_service.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, required this.currentUser});

  final String currentUser;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();

  List<UserProfile> _searchResults = [];
  Set<String> _followedUserIds = {};
  List<UserProfile> _followedUsers = [];
  List<UserProfile> _followers = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isLoadingFollowed = false;
  bool _isLoadingFollowers = false;

  @override
  void initState() {
    super.initState();
    _loadFollowedUsers();
    _loadFollowers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowedUsers() async {
    setState(() {
      _isLoadingFollowed = true;
    });

    try {
      final followedUsers = await _userService.getFollowedUsers();
      if (mounted) {
        setState(() {
          _followedUsers = followedUsers;
          _followedUserIds = Set.from(followedUsers.map((u) => u.id));
          _isLoadingFollowed = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading followed users: $e');
      if (mounted) {
        setState(() {
          _isLoadingFollowed = false;
        });
      }
    }
  }

  Future<void> _loadFollowers() async {
    setState(() {
      _isLoadingFollowers = true;
    });

    try {
      final followers = await _userService.getFollowers();
      if (mounted) {
        setState(() {
          _followers = followers;
          _isLoadingFollowers = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading followers: $e');
      if (mounted) {
        setState(() {
          _isLoadingFollowers = false;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final results = await _userService.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _searchResults = [];
        });
      }
    }
  }

  Future<void> _toggleFollow(UserProfile user) async {
    final isFollowing = _followedUserIds.contains(user.id);

    // Optimistic update
    setState(() {
      if (isFollowing) {
        _followedUserIds.remove(user.id);
        _followedUsers.removeWhere((u) => u.id == user.id);
      } else {
        _followedUserIds.add(user.id);
        _followedUsers.add(user);
      }
    });

    try {
      if (isFollowing) {
        await _userService.unfollowUser(user.id);
      } else {
        await _userService.followUser(user.id);
      }
      // Reload to ensure consistency
      await _loadFollowedUsers();
      await _loadFollowers();
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          if (isFollowing) {
            _followedUserIds.add(user.id);
            _followedUsers.add(user);
          } else {
            _followedUserIds.remove(user.id);
            _followedUsers.removeWhere((u) => u.id == user.id);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status: $e')),
        );
      }
    }
  }

  void _openChat(UserProfile user) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatPage(friendName: user.displayName)),
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
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: (value) {
                // Debounce could be added here
                _performSearch(value);
              },
            ),
          ),
          Expanded(child: _buildContent(theme, colors)),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colors) {
    if (_isSearching) {
      if (_searchResults.isEmpty && !_isLoading) {
        return Center(
          child: Text(
            'No users found',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          // Don't show current user in search results
          if (user.id == widget.currentUser) return const SizedBox.shrink();

          final isFollowing = _followedUserIds.contains(user.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _FriendTile(
              profile: user,
              isFollowing: isFollowing,
              onChat: () => _openChat(user),
              onToggleFollow: () => _toggleFollow(user),
            ),
          );
        },
      );
    }

    // Default view (could show suggestions or followed users)
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        _SectionHeading(
          title: 'Search for friends',
          subtitle: 'Find other lazy athletes to follow',
        ),
        const SizedBox(height: 24),
        if (_followedUsers.isNotEmpty) ...[
          _SectionHeading(
            title: 'Your chill crew',
            subtitle: 'People you follow',
          ),
          const SizedBox(height: 12),
          if (_isLoadingFollowed)
            const Center(child: CircularProgressIndicator())
          else
            ..._followedUsers.map((user) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FriendTile(
                  profile: user,
                  isFollowing: true,
                  onChat: () => _openChat(user),
                  onToggleFollow: () => _toggleFollow(user),
                ),
              );
            }),
        ],
        const SizedBox(height: 24),
        if (_followers.isNotEmpty) ...[
          _SectionHeading(
            title: 'Your followers',
            subtitle: 'People who follow you',
          ),
          const SizedBox(height: 12),
          if (_isLoadingFollowers)
            const Center(child: CircularProgressIndicator())
          else
            ..._followers.map((user) {
              final isFollowingBack = _followedUserIds.contains(user.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FriendTile(
                  profile: user,
                  isFollowing: isFollowingBack,
                  onChat: () => _openChat(user),
                  onToggleFollow: () => _toggleFollow(user),
                  showFollowBackLabel: !isFollowingBack,
                ),
              );
            }),
        ],
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.profile,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onChat,
    this.showFollowBackLabel = false,
  });

  final UserProfile profile;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onChat;
  final bool showFollowBackLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Generate a consistent color based on name
    final avatarColor = Colors
        .primaries[profile.displayName.hashCode % Colors.primaries.length];

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
            radius: 28,
            backgroundColor: avatarColor.withValues(alpha: 0.18),
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName.characters.first.toUpperCase()
                        : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.displayName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '@${profile.userName}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                if (profile.bio != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    profile.bio!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: onToggleFollow,
                icon: Icon(isFollowing ? Icons.check : Icons.person_add),
                label: Text(
                  isFollowing
                      ? 'Following'
                      : (showFollowBackLabel ? 'Follow Back' : 'Follow'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing
                      ? colors.primary.withValues(alpha: 0.2)
                      : null,
                  foregroundColor: isFollowing
                      ? colors.primary
                      : colors.onPrimary,
                  minimumSize: const Size(0, 36),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isFollowing ? onChat : null,
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
