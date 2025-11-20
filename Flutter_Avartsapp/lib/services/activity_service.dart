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
          .eq('user_id', userId) // Ensure user can only update their own activities
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
          .eq('user_id', userId); // Ensure user can only delete their own activities
    } on Exception catch (e) {
      throw Exception('Failed to delete activity: ${e.toString()}');
    }
  }
}

