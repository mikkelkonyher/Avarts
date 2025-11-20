import 'package:flutter/material.dart';

class EarnedBadgesPage extends StatelessWidget {
  const EarnedBadgesPage({super.key, required this.doomscrollMinutes});

  final int doomscrollMinutes;

  bool get _hasDoomscrollBadge => doomscrollMinutes >= 300;

  List<_Badge> get _badges => [
    _Badge(
      title: 'Doomscroll Badge',
      description: 'Doomscrolled more than 5 hours in one day',
      icon: Icons.pets,
      color: const Color(0xFFD29922),
      unlocked: _hasDoomscrollBadge,
      isCatIcon: true,
    ),
    const _Badge(
      title: 'Couch Potato Ultra',
      description: 'Logged 8+ hours of couch time in one day',
      icon: Icons.weekend,
      color: Color(0xFF2F81F7),
      unlocked: false,
    ),
    const _Badge(
      title: 'Snack Champion',
      description: 'Balanced every workout with snacks',
      icon: Icons.local_pizza,
      color: Color(0xFFED8B00),
      unlocked: false,
    ),
    const _Badge(
      title: 'Series Speedrunner',
      description: 'Finished a full season in a weekend',
      icon: Icons.tv,
      color: Color(0xFF8957E5),
      unlocked: false,
    ),
    const _Badge(
      title: 'Procrastination Champ',
      description:
          'Congratulations! You avoided every single task on your to-do list today—true mastery of doing nothing.\nZero tasks completed. Absolute avoidance achieved.',
      icon: Icons.hourglass_empty,
      color: Color(0xFF3FB950),
      unlocked: false,
    ),
    const _Badge(
      title: 'Lieutenant Dan',
      description:
          'Barely walking. Less than 100 steps in a day. Good job you fat fuck!',
      icon: Icons.accessible,
      color: Color(0xFFFF6B6B),
      unlocked: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Earned badges')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        itemBuilder: (context, index) {
          final badge = _badges[index];
          final accent = badge.unlocked
              ? badge.color
              : colors.onSurface.withValues(alpha: 0.2);
          final bgColor = badge.unlocked
              ? badge.color.withValues(alpha: 0.12)
              : colors.surfaceContainerHighest.withValues(alpha: 0.6);

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: badge.unlocked
                    ? badge.color.withValues(alpha: 0.4)
                    : colors.surfaceContainerHighest,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BadgeIcon(badge: badge, accent: accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              badge.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: badge.unlocked
                                    ? colors.onSurface
                                    : colors.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _BadgeStatus(unlocked: badge.unlocked),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        badge.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemCount: _badges.length,
      ),
    );
  }
}

class _Badge {
  const _Badge({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
    this.isCatIcon = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;
  final bool isCatIcon;
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.badge, required this.accent});

  final _Badge badge;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: accent.withValues(alpha: 0.15),
      child: badge.isCatIcon
          ? Text(
              '🐱',
              style: TextStyle(
                fontSize: 26,
                color: badge.unlocked ? accent : accent.withValues(alpha: 0.8),
              ),
            )
          : Icon(badge.icon, color: accent, size: 28),
    );
  }
}

class _BadgeStatus extends StatelessWidget {
  const _BadgeStatus({required this.unlocked});

  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: unlocked
            ? colors.primary.withValues(alpha: 0.15)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.check_circle : Icons.lock,
            size: 16,
            color: unlocked
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            unlocked ? 'Unlocked' : 'Locked',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: unlocked
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
