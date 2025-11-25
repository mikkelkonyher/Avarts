import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:avarts/models/notification_item.dart';
import 'package:avarts/services/auth_service.dart';

class NotificationService {
  SupabaseClient get client => Supabase.instance.client;
  String? get currentUserId => AuthService().currentUser?.id;

  Future<List<NotificationItem>> getNotifications() async {
    final userId = currentUserId;
    if (userId == null) {
      return [];
    }

    try {
      // 1. Get all activities created by the user (with titles)
      final activities = await client
          .from('activities')
          .select('id, title')
          .eq('user_id', userId);

      final activityList = activities as List;
      final activityIds = activityList.map((a) => a['id'] as String).toList();

      // Create a map of activity IDs to titles for quick lookup
      final activityTitles = {
        for (var activity in activityList)
          activity['id'] as String: activity['title'] as String,
      };

      // 2. Get all comments on these activities (to find replies/reactions)
      // We need comments where the USER is the author, to find replies/reactions to them
      final userComments = await client
          .from('activity_comments')
          .select('id, activity_id')
          .eq('user_id', userId);

      final userCommentIds = (userComments as List)
          .map((c) => c['id'] as String)
          .toList();

      List<NotificationItem> notifications = [];

      // 3. Fetch Kudos on user's activities
      if (activityIds.isNotEmpty) {
        final kudos = await client
            .from('activity_kudos')
            .select('user_id, activity_id, created_at')
            .inFilter('activity_id', activityIds)
            .neq('user_id', userId); // Exclude self-kudos

        for (final kudo in kudos) {
          final activityId = kudo['activity_id'] as String;
          notifications.add(
            NotificationItem(
              id: 'kudo_${kudo['activity_id']}_${kudo['user_id']}_${kudo['created_at']}',
              type: NotificationType.kudo,
              actorId: kudo['user_id'] as String,
              actorName: await _getUserName(kudo['user_id'] as String),
              activityId: activityId,
              activityTitle: activityTitles[activityId],
              createdAt: DateTime.parse(kudo['created_at'] as String),
            ),
          );
        }

        // 4. Fetch Comments on user's activities
        final comments = await client
            .from('activity_comments')
            .select('id, user_id, activity_id, created_at')
            .inFilter('activity_id', activityIds)
            .neq('user_id', userId) // Exclude self-comments
            .isFilter('parent_comment_id', null); // Only top-level comments

        for (final comment in comments) {
          notifications.add(
            NotificationItem(
              id: comment['id'] as String,
              type: NotificationType.comment,
              actorId: comment['user_id'] as String,
              actorName: await _getUserName(comment['user_id'] as String),
              activityId: comment['activity_id'] as String,
              commentId: comment['id'] as String,
              createdAt: DateTime.parse(comment['created_at'] as String),
            ),
          );
        }
      }

      // 5. Fetch Replies to user's comments
      if (userCommentIds.isNotEmpty) {
        final replies = await client
            .from('activity_comments')
            .select('id, user_id, activity_id, created_at, parent_comment_id')
            .inFilter('parent_comment_id', userCommentIds)
            .neq('user_id', userId);

        for (final reply in replies) {
          notifications.add(
            NotificationItem(
              id: reply['id'] as String,
              type: NotificationType.reply,
              actorId: reply['user_id'] as String,
              actorName: await _getUserName(reply['user_id'] as String),
              activityId: reply['activity_id'] as String,
              commentId: reply['id'] as String,
              createdAt: DateTime.parse(reply['created_at'] as String),
            ),
          );
        }

        // 6. Fetch Reactions to user's comments
        final reactions = await client
            .from('comment_reactions')
            .select('user_id, comment_id, created_at, emoji')
            .inFilter('comment_id', userCommentIds)
            .neq('user_id', userId);

        // Need to map comment_id back to activity_id
        final commentActivityMap = {
          for (var c in userComments)
            c['id'] as String: c['activity_id'] as String,
        };

        for (final reaction in reactions) {
          final commentId = reaction['comment_id'] as String;
          final activityId = commentActivityMap[commentId];

          if (activityId != null) {
            notifications.add(
              NotificationItem(
                id: 'reaction_${reaction['comment_id']}_${reaction['user_id']}_${reaction['created_at']}',
                type: NotificationType.reaction,
                actorId: reaction['user_id'] as String,
                actorName: await _getUserName(reaction['user_id'] as String),
                activityId: activityId,
                commentId: commentId,
                createdAt: DateTime.parse(reaction['created_at'] as String),
              ),
            );
          }
        }
      }

      // Sort by date descending
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return notifications;
    } catch (e) {
      // In production, you would use a proper logging framework here
      // For now, we'll silently fail and return empty list
      return [];
    }
  }

  // Cache for user names to avoid repeated lookups
  final Map<String, String> _userNameCache = {};

  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    try {
      final profile = await client
          .from('profiles')
          .select('user_name')
          .eq('id', userId)
          .maybeSingle();

      final name = profile?['user_name'] as String? ?? 'User';
      _userNameCache[userId] = name;
      return name;
    } catch (e) {
      return 'User';
    }
  }
}
