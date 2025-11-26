/// Model representing a user profile
class UserProfile {
  const UserProfile({
    required this.id,
    required this.userName,
    required this.displayName,
    this.avatarUrl,
    this.bio,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      userName: json['user_name'] as String? ?? 'Unknown',
      displayName:
          json['display_name'] as String? ??
          json['user_name'] as String? ??
          'Unknown',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
    );
  }

  final String id;
  final String userName;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
}
