// Package imports
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Custom exception for authentication-related errors
class AuthException implements Exception {
  AuthException(this.message);

  /// Error message describing what went wrong
  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Result object returned from a successful login attempt
class LoginResult {
  LoginResult({
    required this.user,
    this.token,
  });

  /// Supabase user object
  final User user;

  /// Authentication token (access token)
  final String? token;

  /// Gets a display name for the user, trying multiple fallback strategies:
  /// 1. user_metadata userName (preferred)
  /// 2. user_metadata full_name
  /// 3. user_metadata first_name
  /// 4. Email username (part before @)
  /// 5. Default fallback
  String get displayName {
    final metadata = user.userMetadata ?? {};

    // Try userName from metadata first (preferred)
    final userName = metadata['userName'] as String?;
    if (userName != null && userName.isNotEmpty) {
      return userName;
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

    // Extract username from email (part before @)
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    // Fallback to default
    return email ?? 'Avarts Legend';
  }
}

/// Service class for handling authentication with Supabase
class AuthService {
  /// Gets the Supabase client instance
  SupabaseClient get client => Supabase.instance.client;

  /// Gets the current user session
  User? get currentUser => client.auth.currentUser;

  /// Checks if user is currently logged in
  bool get isLoggedIn => currentUser != null;

  /// Initializes Supabase with credentials from environment variables
  /// Must be called before using any auth methods
  static Future<void> initialize() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      throw AuthException('SUPABASE_URL missing from .env');
    }
    if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
      throw AuthException('SUPABASE_ANON_KEY missing from .env');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  /// Registers a new user with email and password
  ///
  /// [email] - User's email address
  /// [password] - User's password (minimum 6 characters)
  /// [userName] - Optional username (used as display name)
  ///
  /// Throws [AuthException] if registration fails
  ///
  /// Note: Profile is automatically created by database trigger using display_name from metadata
  Future<void> registerUser({
    required String email,
    required String password,
    String? userName,
  }) async {
    try {
      // Build user metadata
      // The trigger looks for 'display_name' in raw_user_meta_data to set user_name in profiles
      final metadata = <String, dynamic>{};
      if (userName != null && userName.isNotEmpty) {
        metadata['display_name'] = userName; // Trigger uses this to set user_name in profiles
        metadata['userName'] = userName; // Keep for backward compatibility
        metadata['full_name'] = userName; // Keep for backward compatibility
      }

      // Get email verification redirect URL from environment
      final emailRedirectUrl = dotenv.env['SUPABASE_EMAIL_REDIRECT_URL'] ?? 
          'avarts://email-verified';

      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: metadata.isNotEmpty ? metadata : null,
        emailRedirectTo: emailRedirectUrl,
      );

      if (response.user == null) {
        throw AuthException('Registration failed: No user returned');
      }

      // Profile is automatically created by the database trigger
      // No need to manually create/update it here
    } on AuthException {
      rethrow;
    } on Exception catch (e) {
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  /// Logs in a user with email and password
  ///
  /// Returns [LoginResult] on success
  /// Throws [AuthException] if login fails
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw AuthException('Login failed: No user returned');
      }

      // Ensure profile is set up correctly (update display_name if needed)
      await _ensureProfileSetup(response.user!);

      return LoginResult(
        user: response.user!,
        token: response.session?.accessToken,
      );
    } on AuthException {
      rethrow;
    } on Exception catch (e) {
      throw AuthException('Login failed: ${e.toString()}');
    }
  }

  /// Sends a password reset email to the user
  ///
  /// [email] - User's email address
  /// Throws [AuthException] if the request fails
  ///
  /// Note: The redirect URL must be added to your Supabase dashboard
  /// under Authentication > URL Configuration > Redirect URLs
  /// Also check that Site URL is configured correctly
  /// Default uses: avarts://reset-password
  /// You can override with SUPABASE_REDIRECT_URL in .env
  Future<void> resetPassword({required String email}) async {
    try {
      // Get redirect URL from environment or use a default
      // This URL must be added to Supabase dashboard > Authentication > Redirect URLs
      final redirectUrl = dotenv.env['SUPABASE_REDIRECT_URL'] ?? 
          'avarts://reset-password';
      
      // Ensure the redirect URL is properly formatted
      // For deep links like avarts://reset-password, the host will be 'reset-password'
      final uri = Uri.parse(redirectUrl);
      if (uri.scheme.isEmpty) {
        throw AuthException('Invalid redirect URL format: $redirectUrl (missing scheme)');
      }
      
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );
    } on AuthException {
      rethrow;
    } on Exception catch (e) {
      throw AuthException('Password reset failed: ${e.toString()}');
    }
  }

  /// Logs in a user with Google OAuth
  ///
  /// For mobile: Opens the OAuth provider in browser/app
  /// For web: Redirects to OAuth provider
  /// Returns [LoginResult] on success
  /// Throws [AuthException] if login fails
  Future<LoginResult> signInWithGoogle() async {
    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: null, // You can set a custom redirect URL if needed
      );

      // Wait for the OAuth flow to complete and session to be established
      // Poll for session with timeout
      const maxWaitTime = Duration(seconds: 30);
      const pollInterval = Duration(milliseconds: 500);
      final startTime = DateTime.now();

      while (DateTime.now().difference(startTime) < maxWaitTime) {
        final session = client.auth.currentSession;
        if (session != null) {
          // Ensure profile is set up correctly
          await _ensureProfileSetup(session.user);
          return LoginResult(
            user: session.user,
            token: session.accessToken,
          );
        }
        await Future.delayed(pollInterval);
      }

      throw AuthException('OAuth login timed out. Please try again.');
    } on AuthException {
      rethrow;
    } on Exception catch (e) {
      throw AuthException('Google login failed: ${e.toString()}');
    }
  }

  /// Logs in a user with GitHub OAuth
  ///
  /// For mobile: Opens the OAuth provider in browser/app
  /// For web: Redirects to OAuth provider
  /// Returns [LoginResult] on success
  /// Throws [AuthException] if login fails
  Future<LoginResult> signInWithGitHub() async {
    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: null, // You can set a custom redirect URL if needed
      );

      // Wait for the OAuth flow to complete and session to be established
      // Poll for session with timeout
      const maxWaitTime = Duration(seconds: 30);
      const pollInterval = Duration(milliseconds: 500);
      final startTime = DateTime.now();

      while (DateTime.now().difference(startTime) < maxWaitTime) {
        final session = client.auth.currentSession;
        if (session != null) {
          // Ensure profile is set up correctly
          await _ensureProfileSetup(session.user);
          return LoginResult(
            user: session.user,
            token: session.accessToken,
          );
        }
        await Future.delayed(pollInterval);
      }

      throw AuthException('OAuth login timed out. Please try again.');
    } on AuthException {
      rethrow;
    } on Exception catch (e) {
      throw AuthException('GitHub login failed: ${e.toString()}');
    }
  }

  /// Logs out the current user
  Future<void> logout() async {
    try {
      await client.auth.signOut();
    } on Exception catch (e) {
      throw AuthException('Logout failed: ${e.toString()}');
    }
  }

  /// Gets the current session
  Session? get currentSession => client.auth.currentSession;

  /// Handles deep link for password reset
  /// Extracts tokens from the URL and exchanges them for a session
  Future<void> handlePasswordResetLink(String url) async {
    try {
      final uri = Uri.parse(url);
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];

      if (accessToken != null && refreshToken != null) {
        // Exchange the tokens for a session
        // This establishes the session so the user can reset their password
        await client.auth.setSession(refreshToken);
      } else {
        throw AuthException('Missing access_token or refresh_token in password reset link');
      }
    } on Exception catch (e) {
      throw AuthException('Failed to handle password reset link: ${e.toString()}');
    }
  }

  /// Handles deep link for email verification
  /// Extracts tokens from the URL and verifies the email
  Future<void> handleEmailVerificationLink(String url) async {
    try {
      final uri = Uri.parse(url);
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];
      final type = uri.queryParameters['type'];

      if (type == 'signup' && accessToken != null && refreshToken != null) {
        // Exchange the tokens for a session to verify email
        await client.auth.setSession(refreshToken);
        // Ensure profile is set up correctly after email verification
        final user = client.auth.currentUser;
        if (user != null) {
          await _ensureProfileSetup(user);
        }
      }
    } on Exception catch (e) {
      throw AuthException('Failed to handle email verification link: ${e.toString()}');
    }
  }

  /// Ensures the user's profile is set up correctly with user_name
  /// Updates profile if user_name from metadata doesn't match profile
  Future<void> _ensureProfileSetup(User user) async {
    try {
      final metadata = user.userMetadata ?? {};
      // Try display_name first (used by trigger), then userName for backward compatibility
      final userName = metadata['display_name'] as String? ?? 
                       metadata['userName'] as String?;

      // If we have a userName in metadata, ensure profile uses it
      if (userName != null && userName.isNotEmpty) {
        // Check current profile
        final profile = await client
            .from('profiles')
            .select('user_name')
            .eq('id', user.id)
            .maybeSingle();

        // Update profile if user_name doesn't match
        if (profile == null || 
            (profile['user_name'] as String?) != userName) {
          await client.from('profiles').upsert({
            'id': user.id,
            'user_name': userName,
          });
        }
      }
    } catch (e) {
      // Profile update might fail if table doesn't exist or permissions issue
      // Log but don't fail login
      // ignore: avoid_print
      print('Warning: Failed to ensure profile setup: $e');
    }
  }
}

