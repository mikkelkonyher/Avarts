import 'package:flutter/material.dart';
import 'package:avarts/pages/earned_badges_page.dart';
import 'package:avarts/pages/friends_page.dart';
import 'package:avarts/pages/login_page.dart';
import 'package:avarts/pages/log_activity_page.dart';
import 'package:avarts/pages/activity_feed_page.dart';
import 'package:avarts/services/auth_service.dart';
import 'package:avarts/services/activity_service.dart';
import 'package:avarts/models/activity_post.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key, required this.loginResult});

  final LoginResult loginResult;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ActivityService _activityService = ActivityService();

  // Real activities data from Supabase
  List<ActivityPost> _activities = [];
  bool _isLoadingActivities = true;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
        // Refresh activities when switching to Activities tab
        if (_tabController.index == 1 && !_isLoadingActivities) {
          _loadActivities();
        }
      }
    });
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoadingActivities = true);
    try {
      final activitiesData = await _activityService.getUserActivities();
      setState(() {
        _activities = activitiesData.map((data) {
          // Handle image_url - it might be null or empty string
          final imageUrl = data['image_url'];
          final mediaUrl = (imageUrl is String && imageUrl.isNotEmpty)
              ? imageUrl
              : null;

          return ActivityPost(
            id: data['id'] as String?,
            author: widget.loginResult.displayName,
            activity: data['activity'] as String,
            title: data['title'] as String,
            description: data['description'] as String? ?? '',
            duration: Duration(minutes: data['time_minutes'] as int),
            createdAt: DateTime.parse(data['created_at'] as String),
            mediaUrl: mediaUrl,
          );
        }).toList();
        _isLoadingActivities = false;
      });
    } catch (e) {
      setState(() => _isLoadingActivities = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load activities: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_ChillStat> get _stats {
    // Calculate stats from real activities
    final Map<String, int> activityMinutes = {};

    for (final activity in _activities) {
      final minutes = activity.duration.inMinutes;
      activityMinutes[activity.activity] =
          (activityMinutes[activity.activity] ?? 0) + minutes;
    }

    // Convert to list of stats
    final stats = <_ChillStat>[];

    // Map activity types to icons and colors
    final activityConfig = {
      'Nap on Couch': (icon: Icons.weekend, color: Color(0xFF2F81F7)),
      'Netflix marathons': (icon: Icons.tv, color: Color(0xFF8957E5)),
      'Bingewatching': (icon: Icons.movie_filter, color: Color(0xFF238636)),
      'Bingewatching classics': (
        icon: Icons.movie_filter,
        color: Color(0xFF238636),
      ),
      'Doomscrolling': (icon: Icons.swipe_up, color: Color(0xFFD29922)),
      'Doomscrolling cat videos': (
        icon: Icons.swipe_up,
        color: Color(0xFFD29922),
      ),
      'Snack break': (icon: Icons.local_pizza, color: Color(0xFFED8B00)),
      'Meditation attempt': (
        icon: Icons.self_improvement,
        color: Color(0xFF3FB950),
      ),
      'Pro-level procrastination': (
        icon: Icons.hourglass_empty,
        color: Color(0xFFFF6B6B),
      ),
    };

    activityMinutes.forEach((activity, minutes) {
      final config =
          activityConfig[activity] ??
          (icon: Icons.fitness_center, color: Color(0xFF2F81F7));
      stats.add(
        _ChillStat(
          label: activity,
          minutes: minutes,
          icon: config.icon,
          color: config.color,
        ),
      );
    });

    // Sort by minutes descending
    stats.sort((a, b) => b.minutes.compareTo(a.minutes));

    return stats;
  }

  int get _doomscrollMinutes => _stats
      .firstWhere(
        (stat) => stat.label == 'Doomscrolling',
        orElse: () => _ChillStat(
          label: 'Doomscrolling',
          minutes: 0,
          icon: Icons.swipe_up,
          color: Color(0xFFD29922),
        ),
      )
      .minutes;

  int get _totalMinutes =>
      _stats.fold<int>(0, (sum, stat) => sum + stat.minutes);

  Future<void> _openLogActivity() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            LogActivityPage(currentUser: widget.loginResult.displayName),
      ),
    );

    if (result == true) {
      // Activity was posted successfully, refresh the list
      _loadActivities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity posted successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteActivity(int index) async {
    final activity = _activities[index];
    if (activity.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete activity: missing ID')),
      );
      return;
    }

    try {
      await _activityService.deleteActivity(activity.id!);
      setState(() {
        _activities.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Activity deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete activity: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _editActivity(int index) async {
    final activity = _activities[index];
    if (activity.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit activity: missing ID')),
      );
      return;
    }

    final result = await _showEditDialog(activity);
    if (result != null) {
      try {
        final totalMinutes = result.duration.inMinutes;
        await _activityService.updateActivity(
          activityId: activity.id!,
          title: result.title,
          activity: result.activity,
          description: result.description,
          timeMinutes: totalMinutes,
          imageUrl: result.mediaUrl,
        );

        setState(() {
          _activities[index] = result;
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Activity updated')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update activity: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<ActivityPost?> _showEditDialog(ActivityPost activity) async {
    final titleController = TextEditingController(text: activity.title);
    final descriptionController = TextEditingController(
      text: activity.description,
    );

    final activities = const [
      'Nap on Couch',
      'Bingewatching',
      'Netflix marathons',
      'Doomscrolling',
      'Snack break',
      'Meditation attempt',
      'Pro-level procrastination',
    ];

    // Ensure the activity value exists in the dropdown list, otherwise set to null
    String? selectedActivity = activities.contains(activity.activity)
        ? activity.activity
        : null;
    int hours = activity.duration.inHours;
    int minutes = activity.duration.inMinutes % 60;

    return showDialog<ActivityPost>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Activity'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: selectedActivity,
                      decoration: const InputDecoration(labelText: 'Activity'),
                      hint: selectedActivity == null
                          ? Text(
                              'Select activity (current: ${activity.activity})',
                            )
                          : null,
                      items: activities
                          .map(
                            (text) => DropdownMenuItem(
                              value: text,
                              child: Text(text),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedActivity = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            // ignore: deprecated_member_use
                            value: hours,
                            decoration: const InputDecoration(
                              labelText: 'Hours',
                            ),
                            items: List.generate(
                              13,
                              (i) =>
                                  DropdownMenuItem(value: i, child: Text('$i')),
                            ),
                            onChanged: (value) {
                              setDialogState(() {
                                hours = value ?? hours;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            // ignore: deprecated_member_use
                            value: minutes,
                            decoration: const InputDecoration(
                              labelText: 'Minutes',
                            ),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('00')),
                              DropdownMenuItem(value: 15, child: Text('15')),
                              DropdownMenuItem(value: 30, child: Text('30')),
                              DropdownMenuItem(value: 45, child: Text('45')),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                minutes = value ?? minutes;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    // Use selectedActivity if available, otherwise keep original activity
                    final activityType = selectedActivity ?? activity.activity;
                    if ((hours > 0 || minutes > 0) &&
                        titleController.text.trim().isNotEmpty &&
                        descriptionController.text.trim().isNotEmpty) {
                      Navigator.of(context).pop(
                        ActivityPost(
                          id: activity.id,
                          author: activity.author,
                          activity: activityType,
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim(),
                          duration: Duration(hours: hours, minutes: minutes),
                          createdAt: activity.createdAt,
                          mediaUrl: activity.mediaUrl,
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.self_improvement, color: colors.primary),
            const SizedBox(width: 8),
            const Text('Avarts'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Profile'),
            Tab(text: 'Activities'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Badges Earned Tab
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroCard(
                  name: widget.loginResult.displayName,
                  totalMinutes: _totalMinutes,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FriendsPage(
                                currentUser: widget.loginResult.displayName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.people_alt_rounded),
                        label: const Text('Find friends & chat'),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EarnedBadgesPage(
                                doomscrollMinutes: _doomscrollMinutes,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.emoji_events_outlined),
                        label: const Text('View earned badges'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Chill analytics',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ..._stats.map((stat) {
                  final ratio = stat.minutes / _totalMinutes;
                  final isDoomscrolling = stat.label == 'Doomscrolling';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colors.surfaceContainerHighest,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: stat.color.withValues(
                                  alpha: 0.18,
                                ),
                                child: Icon(stat.icon, color: stat.color),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stat.label,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatMinutes(stat.minutes),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurface.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(ratio * 100).round()}%',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              color: stat.color,
                              backgroundColor: colors.surface,
                            ),
                          ),
                          if (isDoomscrolling) ...[
                            const SizedBox(height: 16),
                            _DoomscrollingMessage(minutes: stat.minutes),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Activities Tab
          _buildActivitiesTab(context, theme, colors),
        ],
      ),
      floatingActionButton: _currentTabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _openLogActivity,
              icon: const Icon(Icons.post_add_rounded),
              label: const Text('Log activity'),
            )
          : null,
    );
  }

  Widget _buildActivitiesTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme colors,
  ) {
    if (_isLoadingActivities) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No activities logged yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadActivities,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        itemCount: _activities.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final activity = _activities[index];
          return _ActivityCard(
            activity: activity,
            loginResult: widget.loginResult,
            onEdit: () => _editActivity(index),
            onDelete: () => _deleteActivity(index),
          );
        },
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '$mins min';
    return '${hours}h ${mins}m';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.name, required this.totalMinutes});

  final String name;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Total Relaxation Time',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatMinutes(totalMinutes),
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '$mins min';
    return '${hours}h ${mins}m';
  }
}

class _ChillStat {
  const _ChillStat({
    required this.label,
    required this.minutes,
    required this.icon,
    required this.color,
  });

  final String label;
  final int minutes;
  final IconData icon;
  final Color color;
}

class _DoomscrollingMessage extends StatelessWidget {
  const _DoomscrollingMessage({required this.minutes});

  final int minutes;

  bool get _isVictory => minutes > 300;

  String get _message => _isVictory
      ? 'You watched more catvideos on instagram than the number of steps you took today. The stats speak for themselves. Awesome keep it up slacker joe!'
      : 'Come on. Those cat videos on Instagram are not going to watch themselves';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = _isVictory ? colors.primary : colors.tertiary;
    final icon = _isVictory ? Icons.pets : Icons.self_improvement;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: accent.withValues(alpha: 0.15),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isVictory ? 'Happy cat victory lap' : 'Low scrolling time',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.loginResult,
    required this.onEdit,
    required this.onDelete,
  });

  final ActivityPost activity;
  final LoginResult loginResult;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours == 0) return '$minutes min';
    return '${hours}h ${minutes}m';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getActivityIcon(String activity) {
    switch (activity) {
      case 'Nap on Couch':
        return Icons.weekend;
      case 'Bingewatching':
      case 'Bingewatching classics':
        return Icons.movie_filter;
      case 'Netflix marathons':
        return Icons.tv;
      case 'Doomscrolling':
      case 'Doomscrolling cat videos':
        return Icons.swipe_up;
      case 'Snack break':
        return Icons.local_pizza;
      case 'Meditation attempt':
        return Icons.self_improvement;
      case 'Pro-level procrastination':
        return Icons.hourglass_empty;
      default:
        return Icons.fitness_center;
    }
  }

  Color _getActivityColor(String activity) {
    switch (activity) {
      case 'Nap on Couch':
        return const Color(0xFF2F81F7);
      case 'Bingewatching':
      case 'Bingewatching classics':
        return const Color(0xFF238636);
      case 'Netflix marathons':
        return const Color(0xFF8957E5);
      case 'Doomscrolling':
      case 'Doomscrolling cat videos':
        return const Color(0xFFD29922);
      case 'Snack break':
        return const Color(0xFFED8B00);
      case 'Meditation attempt':
        return const Color(0xFF3FB950);
      case 'Pro-level procrastination':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF2F81F7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activityColor = _getActivityColor(activity.activity);
    final activityIcon = _getActivityIcon(activity.activity);

    return InkWell(
      onTap: activity.id != null
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActivityFeedPage(
                    loginResult: loginResult,
                    activityIdToHighlight: activity.id,
                  ),
                ),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.surfaceContainerHighest),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: activityColor.withValues(alpha: 0.18),
                child: Icon(activityIcon, color: activityColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activity.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                              onTap: () {
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  onEdit,
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  onDelete,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity.activity,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: activityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activity.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (activity.mediaUrl != null && activity.mediaUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                activity.mediaUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: colors.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: colors.surfaceContainerHighest,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                _formatDuration(activity.duration),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.calendar_today,
                size: 16,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(activity.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
