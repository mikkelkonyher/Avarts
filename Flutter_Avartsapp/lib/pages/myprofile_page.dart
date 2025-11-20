import 'package:flutter/material.dart';
import 'package:flutter_avartsproto/pages/earned_badges_page.dart';
import 'package:flutter_avartsproto/pages/friends_page.dart';
import 'package:flutter_avartsproto/pages/login_page.dart';
import 'package:flutter_avartsproto/services/api_service.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key, required this.loginResult});

  final LoginResult loginResult;

  List<_ChillStat> get _stats => const [
    _ChillStat(
      label: 'Chilling on the couch',
      minutes: 540,
      icon: Icons.weekend,
      color: Color(0xFF2F81F7),
    ),
    _ChillStat(
      label: 'Netflix marathons',
      minutes: 420,
      icon: Icons.tv,
      color: Color(0xFF8957E5),
    ),
    _ChillStat(
      label: 'Bingewatching classics',
      minutes: 315,
      icon: Icons.movie_filter,
      color: Color(0xFF238636),
    ),
    _ChillStat(
      label: 'Doomscrolling',
      minutes: 330,
      icon: Icons.swipe_up,
      color: Color(0xFFD29922),
    ),
  ];

  int get _doomscrollMinutes =>
      _stats.firstWhere((stat) => stat.label == 'Doomscrolling').minutes;

  int get _totalMinutes =>
      _stats.fold<int>(0, (sum, stat) => sum + stat.minutes);

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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroCard(
              name: loginResult.displayName,
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
                          builder: (_) =>
                              FriendsPage(currentUser: loginResult.displayName),
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
                    border: Border.all(color: colors.surfaceContainerHighest),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: stat.color.withValues(alpha: 0.18),
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
                                  style: theme.textTheme.bodySmall?.copyWith(
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
