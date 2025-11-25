// Package imports
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:avarts/services/auth_service.dart';

/// Service class for handling activity-related operations with Supabase
class ActivityService {
  /// Gets the Supabase client instance
  SupabaseClient get client => Supabase.instance.client;

  /// Gets the current user ID
  String? get currentUserId => AuthService().currentUser?.id;

  /// Posts a new activity to Supabase
  ///
  /// [title] - Activity title
  /// [activity] - Type of activity
  /// [description] - Activity description (optional)
  /// [timeMinutes] - Duration in minutes
  /// [imageUrl] - URL of uploaded image (optional)
  ///
  /// Returns the created activity record
  /// Throws [Exception] if posting fails
  Future<Map<String, dynamic>> postActivity({
    required String title,
    required String activity,
    String? description,
    required int timeMinutes,
    String? imageUrl,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to post activities');
    }

    try {
      final response = await client
          .from('activities')
          .insert({
            'user_id': userId,
            'title': title,
            'activity': activity,
            'description': description,
            'time_minutes': timeMinutes,
            'image_url': imageUrl,
          })
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to post activity: ${e.message}');
    } on Exception catch (e) {
      throw Exception('Failed to post activity: ${e.toString()}');
    }
  }

  /// Fetches activities from Supabase
  ///
  /// [limit] - Maximum number of activities to fetch (default: 50)
  /// [offset] - Number of activities to skip (for pagination)
  ///
  /// Returns a list of activity records
  Future<List<Map<String, dynamic>>> getActivities({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await client
          .from('activities')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } on Exception catch (e) {
      throw Exception('Failed to fetch activities: ${e.toString()}');
    }
  }

  /// Fetches activities for the current user
  ///
  /// [limit] - Maximum number of activities to fetch (default: 50)
  /// [offset] - Number of activities to skip (for pagination)
  ///
  /// Returns a list of activity records for the current user
  Future<List<Map<String, dynamic>>> getUserActivities({
    int limit = 50,
    int offset = 0,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to fetch activities');
    }

    try {
      final response = await client
          .from('activities')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } on Exception catch (e) {
      throw Exception('Failed to fetch user activities: ${e.toString()}');
    }
  }

  /// Updates an existing activity
  ///
  /// [activityId] - ID of the activity to update
  /// [title] - Activity title
  /// [activity] - Type of activity
  /// [description] - Activity description (optional)
  /// [timeMinutes] - Duration in minutes
  /// [imageUrl] - URL of uploaded image (optional)
  ///
  /// Returns the updated activity record
  /// Throws [Exception] if update fails
  Future<Map<String, dynamic>> updateActivity({
    required String activityId,
    required String title,
    required String activity,
    String? description,
    required int timeMinutes,
    String? imageUrl,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to update activities');
    }

    try {
      final response = await client
          .from('activities')
          .update({
            'title': title,
            'activity': activity,
            'description': description,
            'time_minutes': timeMinutes,
            'image_url': imageUrl,
          })
          .eq('id', activityId)
          .eq(
            'user_id',
            userId,
          ) // Ensure user can only update their own activities
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update activity: ${e.message}');
    } on Exception catch (e) {
      throw Exception('Failed to update activity: ${e.toString()}');
    }
  }

  /// Deletes an activity
  ///
  /// [activityId] - ID of the activity to delete
  ///
  /// Throws [Exception] if deletion fails
  Future<void> deleteActivity(String activityId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to delete activities');
    }

    try {
      await client
          .from('activities')
          .delete()
          .eq('id', activityId)
          .eq(
            'user_id',
            userId,
          ); // Ensure user can only delete their own activities
    } on Exception catch (e) {
      throw Exception('Failed to delete activity: ${e.toString()}');
    }
  }

  /// Gets display name for a user from their user_id (using public profile if available)
  ///
  /// [userId] - The user ID to get display name for
  ///
  /// Returns the user's display name or a fallback
  String _getUserDisplayNameFromMetadata(
    Map<String, dynamic>? metadata,
    String? email,
  ) {
    if (metadata == null) {
      if (email != null && email.contains('@')) {
        return email.split('@').first;
      }
      return 'Avarts Legend';
    }

    // Try full_name from metadata
    final fullName = metadata['full_name'] as String?;
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    // Try first_name from metadata
    final firstName = metadata['first_name'] as String?;
    if (firstName != null && firstName.isNotEmpty) {
      return firstName;
    }

    // Try userName from metadata
    final userName = metadata['userName'] as String?;
    if (userName != null && userName.isNotEmpty) {
      return userName;
    }

    // Extract username from email (part before @)
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    // Fallback to default
    return email ?? 'Avarts Legend';
  }

  /// Fetches activities for the feed with kudos and comments
  ///
  /// [limit] - Maximum number of activities to fetch (default: 50)
  /// [offset] - Number of activities to skip (for pagination)
  ///
  /// Returns a list of activity records with kudos count, comments, and user info
  Future<List<Map<String, dynamic>>> getFeedActivities({
    int limit = 50,
    int offset = 0,
  }) async {
    final currentUserId = this.currentUserId;

    try {
      // Fetch activities
      final activitiesResponse = await client
          .from('activities')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final activities = List<Map<String, dynamic>>.from(activitiesResponse);

      if (activities.isEmpty) {
        return [];
      }

      // Extract all activity IDs
      final activityIds = activities
          .map((a) => a['id'] as String)
          .toSet(); // Use Set for faster lookup

      // Build OR condition for activity_ids
      // Fetch all kudos and filter in memory (more efficient than per-activity queries)
      final kudosResponse = activityIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await client.from('activity_kudos').select('activity_id, user_id');

      final allKudos = List<Map<String, dynamic>>.from(kudosResponse);
      // Filter to only kudos for our activities
      final kudosList = allKudos
          .where((k) => activityIds.contains(k['activity_id'] as String))
          .toList();

      // Fetch all comments and filter in memory
      final commentsResponse = activityIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await client
                .from('activity_comments')
                .select()
                .order('created_at', ascending: true);

      final allComments = List<Map<String, dynamic>>.from(commentsResponse);
      // Filter to only comments for our activities
      final commentsList = allComments
          .where((c) => activityIds.contains(c['activity_id'] as String))
          .toList();

      // Extract all comment IDs
      final commentIds = commentsList.map((c) => c['id'] as String).toSet();

      // Fetch all reactions for these comments
      final reactionsResponse = commentIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await client
                .from('comment_reactions')
                .select()
                .order('created_at', ascending: true);

      final allReactions = List<Map<String, dynamic>>.from(reactionsResponse);
      // Filter to only reactions for our comments
      final reactionsList = allReactions
          .where((r) => commentIds.contains(r['comment_id'] as String))
          .toList();

      // Group reactions by comment_id
      final reactionsByComment = <String, List<Map<String, dynamic>>>{};
      for (final reaction in reactionsList) {
        final commentId = reaction['comment_id'] as String;
        reactionsByComment.putIfAbsent(commentId, () => []).add(reaction);
      }

      // Group kudos by activity_id
      final kudosByActivity = <String, List<Map<String, dynamic>>>{};
      for (final kudo in kudosList) {
        final activityId = kudo['activity_id'] as String;
        kudosByActivity.putIfAbsent(activityId, () => []).add(kudo);
      }

      // Group comments by activity_id
      final commentsByActivity = <String, List<Map<String, dynamic>>>{};
      for (final comment in commentsList) {
        final activityId = comment['activity_id'] as String;
        commentsByActivity.putIfAbsent(activityId, () => []).add(comment);
      }

      // Collect all unique user IDs to fetch profiles in batch
      final Set<String> userIds = {};
      for (final activity in activities) {
        userIds.add(activity['user_id'] as String);
      }
      for (final comment in commentsList) {
        userIds.add(comment['user_id'] as String);
      }

      // Batch fetch all profiles
      // Build OR condition or fetch all and filter
      final profilesResponse = userIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await client.from('profiles').select('id, user_name');

      final allProfiles = List<Map<String, dynamic>>.from(profilesResponse);
      // Filter to only profiles we need
      final profilesList = allProfiles
          .where((p) => userIds.contains(p['id'] as String))
          .toList();

      final profilesByUserId = <String, Map<String, dynamic>>{};
      for (final profile in profilesList) {
        final userId = profile['id'] as String;
        profilesByUserId[userId] = profile;
      }

      // Helper function to get display name from profile or metadata
      String getUserDisplayName(String userId) {
        // Check if it's the current user
        final currentUser = client.auth.currentUser;
        if (currentUser != null && currentUser.id == userId) {
          return _getUserDisplayNameFromMetadata(
            currentUser.userMetadata,
            currentUser.email,
          );
        }

        // Check profiles table
        final profile = profilesByUserId[userId];
        if (profile != null) {
          final userName = profile['user_name'] as String?;
          if (userName != null && userName.isNotEmpty) {
            return userName;
          }
        }

        return 'User';
      }

      // Build result list
      final List<Map<String, dynamic>> result = [];

      for (final activity in activities) {
        final activityId = activity['id'] as String;
        final userId = activity['user_id'] as String;

        // Get kudos for this activity
        final activityKudos = kudosByActivity[activityId] ?? [];
        final kudosCount = activityKudos.length;
        final hasKudoed =
            currentUserId != null &&
            activityKudos.any((k) => k['user_id'] == currentUserId);

        // Get comments for this activity
        final activityComments = commentsByActivity[activityId] ?? [];

        // Format comments with full data including IDs, reactions, and organize hierarchically
        final List<Map<String, dynamic>> allComments = [];
        for (final comment in activityComments) {
          final commentId = comment['id'] as String;
          final commentUserId = comment['user_id'] as String;
          final commentContent = comment['content'] as String;
          final commentCreatedAt = comment['created_at'] as String;
          final parentCommentId = comment['parent_comment_id'] as String?;
          final authorName = getUserDisplayName(commentUserId);

          // Get reactions for this comment
          final commentReactions = reactionsByComment[commentId] ?? [];
          final reactionsData = commentReactions.map((reaction) {
            return {
              'id': reaction['id'] as String,
              'user_id': reaction['user_id'] as String,
              'emoji': reaction['emoji'] as String,
              'created_at': reaction['created_at'] as String,
            };
          }).toList();

          allComments.add({
            'id': commentId,
            'user_id': commentUserId,
            'author': authorName,
            'content': commentContent,
            'created_at': commentCreatedAt,
            'parent_comment_id': parentCommentId,
            'reactions': reactionsData,
          });
        }

        // Organize comments hierarchically: separate top-level comments and replies
        final List<Map<String, dynamic>> topLevelComments = [];
        final Map<String, List<Map<String, dynamic>>> repliesByParent = {};

        for (final comment in allComments) {
          final parentId = comment['parent_comment_id'] as String?;
          if (parentId == null) {
            // Top-level comment
            topLevelComments.add(comment);
          } else {
            // Reply to a comment
            repliesByParent.putIfAbsent(parentId, () => []).add(comment);
          }
        }

        // Build hierarchical structure - recursively add replies to comments
        List<Map<String, dynamic>> buildCommentTree(
          Map<String, dynamic> comment,
        ) {
          final commentId = comment['id'] as String;
          final directReplies = repliesByParent[commentId] ?? [];
          return directReplies.map((reply) {
            return {...reply, 'replies': buildCommentTree(reply)};
          }).toList();
        }

        final List<Map<String, dynamic>> commentData = [];
        for (final topLevelComment in topLevelComments) {
          commentData.add({
            ...topLevelComment,
            'replies': buildCommentTree(topLevelComment),
          });
        }

        // Get author display name
        final authorName = getUserDisplayName(userId);

        // Combine all data
        result.add({
          ...activity,
          'author_name': authorName,
          'kudos_count': kudosCount,
          'has_kudoed': hasKudoed,
          'comments': commentData,
        });
      }

      return result;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch feed activities: ${e.message}');
    } on Exception catch (e) {
      throw Exception('Failed to fetch feed activities: ${e.toString()}');
    }
  }

  /// Adds a kudo to an activity
  ///
  /// [activityId] - ID of the activity to kudo
  ///
  /// Throws [Exception] if adding kudo fails
  Future<void> addKudos(String activityId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to give kudos');
    }

    try {
      // Check if user already kudoed
      final existing = await client
          .from('activity_kudos')
          .select()
          .eq('activity_id', activityId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Already kudoed, remove it (toggle behavior)
        await client
            .from('activity_kudos')
            .delete()
            .eq('activity_id', activityId)
            .eq('user_id', userId);
      } else {
        // Add kudo
        await client.from('activity_kudos').insert({
          'activity_id': activityId,
          'user_id': userId,
        });
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to add kudo: ${e.message}');
    } on Exception catch (e) {
      throw Exception('Failed to add kudo: ${e.toString()}');
    }
  }

  /// Adds a comment to an activity
  ///
  /// [activityId] - ID of the activity to comment on
  /// [content] - The comment content
  /// [parentCommentId] - Optional ID of the parent comment if this is a reply
  ///
  /// Returns the created comment record
  /// Throws [Exception] if adding comment fails
  Future<Map<String, dynamic>> addComment({
    required String activityId,
    required String content,
    String? parentCommentId,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to comment');
    }

    try {
      final Map<String, dynamic> insertData = {
        'activity_id': activityId,
        'user_id': userId,
        'content': content,
      };

      if (parentCommentId != null) {
        insertData['parent_comment_id'] = parentCommentId;
      }

      final response = await client
          .from('activity_comments')
          .insert(insertData)
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to add comment: ${e.message}');
    } on Exception catch (e) {
      throw Exception('Failed to add comment: ${e.toString()}');
    }
  }

  /// Deletes a comment
  ///
  /// [commentId] - ID of the comment to delete
  ///
  /// Throws [Exception] if deletion fails
  Future<void> deleteComment(String commentId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to delete comments');
    }

    try {
      await client
          .from('activity_comments')
          .delete()
          .eq('id', commentId)
          .eq(
            'user_id',
            userId,
          ); // Ensure user can only delete their own comments
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete comment: ${e.message}');
    } on Exception catch (e) {
      throw Exception('Failed to delete comment: ${e.toString()}');
    }
  }

  /// Gets the list of users who gave kudos to an activity
  ///
  /// [activityId] - ID of the activity
  ///
  /// Returns a list of user info maps with user_id and display name
  /// Throws [Exception] if fetching fails
  Future<List<Map<String, dynamic>>> getKudosUsers(String activityId) async {
    try {
      // Fetch kudos with user info
      final kudosResponse = await client
          .from('activity_kudos')
          .select('user_id, created_at')
          .eq('activity_id', activityId)
          .order('created_at', ascending: false);

      final kudosList = List<Map<String, dynamic>>.from(kudosResponse);
      if (kudosList.isEmpty) {
        return [];
      }

      // Get unique user IDs
      final userIds = kudosList.map((k) => k['user_id'] as String).toSet();

      // Fetch profiles
      final profilesResponse = await client
          .from('profiles')
          .select('id, user_name')
          .inFilter('id', userIds.toList());

      final profiles = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesByUserId = <String, Map<String, dynamic>>{};
      for (final profile in profiles) {
        profilesByUserId[profile['id'] as String] = profile;
      }

      // Helper to get display name
      String getUserDisplayName(String userId) {
        final currentUser = client.auth.currentUser;
        if (currentUser != null && currentUser.id == userId) {
          return _getUserDisplayNameFromMetadata(
            currentUser.userMetadata,
            currentUser.email,
          );
        }

        final profile = profilesByUserId[userId];
        if (profile != null) {
          final userName = profile['user_name'] as String?;
          if (userName != null && userName.isNotEmpty) {
            return userName;
          }
        }

        return 'User';
      }

      // Build result with user info
      return kudosList.map((kudo) {
        final userId = kudo['user_id'] as String;
        return {
          'user_id': userId,
          'display_name': getUserDisplayName(userId),
          'created_at': kudo['created_at'] as String,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch kudos users: ${e.message}');
    } on Exception catch (e) {
      throw Exception('Failed to fetch kudos users: ${e.toString()}');
    }
  }

  /// Gets the list of users who reacted to a comment with a specific emoji
  ///
  /// [commentId] - ID of the comment
  /// [emoji] - The emoji to filter by (optional, if null returns all reactions)
  ///
  /// Returns a list of user info maps with user_id, display name, and emoji
  /// Throws [Exception] if fetching fails
  Future<List<Map<String, dynamic>>> getReactionUsers(
    String commentId, {
    String? emoji,
  }) async {
    try {
      // Build query
      var queryBuilder = client
          .from('comment_reactions')
          .select('user_id, emoji, created_at')
          .eq('comment_id', commentId);

      if (emoji != null) {
        queryBuilder = queryBuilder.eq('emoji', emoji);
      }

      final reactionsResponse = await queryBuilder.order(
        'created_at',
        ascending: false,
      );

      final reactionsList = List<Map<String, dynamic>>.from(reactionsResponse);
      if (reactionsList.isEmpty) {
        return [];
      }

      // Get unique user IDs
      final userIds = reactionsList.map((r) => r['user_id'] as String).toSet();

      // Fetch profiles
      final profilesResponse = await client
          .from('profiles')
          .select('id, user_name')
          .inFilter('id', userIds.toList());

      final profiles = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesByUserId = <String, Map<String, dynamic>>{};
      for (final profile in profiles) {
        profilesByUserId[profile['id'] as String] = profile;
      }

      // Helper to get display name
      String getUserDisplayName(String userId) {
        final currentUser = client.auth.currentUser;
        if (currentUser != null && currentUser.id == userId) {
          return _getUserDisplayNameFromMetadata(
            currentUser.userMetadata,
            currentUser.email,
          );
        }

        final profile = profilesByUserId[userId];
        if (profile != null) {
          final userName = profile['user_name'] as String?;
          if (userName != null && userName.isNotEmpty) {
            return userName;
          }
        }

        return 'User';
      }

      // Build result with user info
      return reactionsList.map((reaction) {
        final userId = reaction['user_id'] as String;
        return {
          'user_id': userId,
          'display_name': getUserDisplayName(userId),
          'emoji': reaction['emoji'] as String,
          'created_at': reaction['created_at'] as String,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch reaction users: ${e.message}');
    } on Exception catch (e) {
      throw Exception('Failed to fetch reaction users: ${e.toString()}');
    }
  }

  /// Adds or removes a reaction to a comment
  /// Users can only have ONE reaction per comment - changing emoji removes the old one
  ///
  /// [commentId] - ID of the comment to react to
  /// [emoji] - The emoji string (e.g., '👍', '❤️', '😂')
  ///
  /// Returns the reaction record if added, null if removed
  /// Throws [Exception] if adding/removing reaction fails
  Future<Map<String, dynamic>?> toggleCommentReaction({
    required String commentId,
    required String emoji,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to react to comments');
    }

    try {
      // Check if user already reacted with this exact emoji
      final existingSameEmoji = await client
          .from('comment_reactions')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .eq('emoji', emoji)
          .maybeSingle();

      if (existingSameEmoji != null) {
        // User already has this exact reaction - remove it (toggle off)
        await client
            .from('comment_reactions')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId)
            .eq('emoji', emoji);
        return null;
      } else {
        // User wants to add/change reaction
        // First, remove any existing reaction from this user (only one allowed)
        await client
            .from('comment_reactions')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);

        // Then add the new reaction
        final response = await client
            .from('comment_reactions')
            .insert({
              'comment_id': commentId,
              'user_id': userId,
              'emoji': emoji,
            })
            .select()
            .single();

        return Map<String, dynamic>.from(response);
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to toggle reaction: ${e.message}');
    } on Exception catch (e) {
      throw Exception('Failed to toggle reaction: ${e.toString()}');
    }
  }
}
