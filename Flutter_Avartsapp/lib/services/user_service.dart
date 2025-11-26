// Package imports
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:avarts/models/user_profile.dart';
import 'package:avarts/services/auth_service.dart';

/// Service class for handling user-related operations
class UserService {
  /// Gets the Supabase client instance
  SupabaseClient get client => Supabase.instance.client;

  /// Gets the current user ID
  String? get currentUserId => AuthService().currentUser?.id;

  /// Searches for users by username or display name
  ///
  /// [query] - The search query
  ///
  /// Returns a list of matching [UserProfile]s
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await client
          .from('profiles')
          .select()
          .or('user_name.ilike.%$query%,display_name.ilike.%$query%')
          .limit(20);

      final data = List<Map<String, dynamic>>.from(response);
      return data.map(UserProfile.fromJson).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error searching users: $e');
      return [];
    }
  }

  /// Follows a user
  ///
  /// [userId] - The ID of the user to follow
  Future<void> followUser(String userId) async {
    final currentId = currentUserId;
    if (currentId == null) throw Exception('Must be logged in to follow users');
    if (currentId == userId) throw Exception('Cannot follow yourself');

    try {
      await client.from('follows').insert({
        'follower_id': currentId,
        'following_id': userId,
      });
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }

  /// Unfollows a user
  ///
  /// [userId] - The ID of the user to unfollow
  Future<void> unfollowUser(String userId) async {
    final currentId = currentUserId;
    if (currentId == null) {
      throw Exception('Must be logged in to unfollow users');
    }

    try {
      await client
          .from('follows')
          .delete()
          .eq('follower_id', currentId)
          .eq('following_id', userId);
    } catch (e) {
      throw Exception('Failed to unfollow user: $e');
    }
  }

  /// Checks if the current user is following a specific user
  ///
  /// [userId] - The ID of the user to check
  Future<bool> isFollowing(String userId) async {
    final currentId = currentUserId;
    if (currentId == null) return false;

    try {
      final response = await client
          .from('follows')
          .select()
          .eq('follower_id', currentId)
          .eq('following_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Gets the list of users followed by the current user
  Future<List<String>> getFollowedUserIds() async {
    final currentId = currentUserId;
    if (currentId == null) return [];

    try {
      final response = await client
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentId);

      final data = List<Map<String, dynamic>>.from(response);
      return data.map((e) => e['following_id'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets the full profiles of users followed by the current user
  Future<List<UserProfile>> getFollowedUsers() async {
    final currentId = currentUserId;
    if (currentId == null) return [];

    try {
      // Join follows with profiles to get full user data
      final response = await client
          .from('follows')
          .select('following_id, profiles!follows_following_id_fkey(*)')
          .eq('follower_id', currentId);

      final data = List<Map<String, dynamic>>.from(response);
      return data
          .map(
            (e) => UserProfile.fromJson(e['profiles'] as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching followed users: $e');
      return [];
    }
  }

  /// Gets the full profiles of users who follow the current user
  Future<List<UserProfile>> getFollowers() async {
    final currentId = currentUserId;
    if (currentId == null) return [];

    try {
      // Join follows with profiles to get full user data of followers
      final response = await client
          .from('follows')
          .select('follower_id, profiles!follows_follower_id_fkey(*)')
          .eq('following_id', currentId);

      final data = List<Map<String, dynamic>>.from(response);
      return data
          .map(
            (e) => UserProfile.fromJson(e['profiles'] as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching followers: $e');
      return [];
    }
  }
}
