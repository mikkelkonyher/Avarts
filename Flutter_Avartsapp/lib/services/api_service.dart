// Dart imports
import 'dart:convert';
import 'dart:io';

// Package imports
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Custom exception for API-related errors
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  /// Error message describing what went wrong
  final String message;

  /// HTTP status code (if available)
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Result object returned from a successful login attempt
class LoginResult {
  LoginResult({required this.raw, this.token, this.user, this.message});

  /// Raw response data from the API
  final Map<String, dynamic> raw;

  /// Authentication token (if provided)
  final String? token;

  /// User data object (if provided)
  final Map<String, dynamic>? user;

  /// Optional message from the API
  final String? message;

  /// Gets a display name for the user, trying multiple fallback strategies:
  /// 1. userName field
  /// 2. firstName field
  /// 3. Email username (part before @)
  /// 4. Default fallback
  String get displayName {
    if (user == null) return 'LazyStrava Legend';

    // Try userName first
    final userName = user!['userName'];
    if (userName != null && userName.toString().isNotEmpty) {
      return userName.toString();
    }

    // Try firstName
    final firstName = user!['firstName'];
    if (firstName != null && firstName.toString().isNotEmpty) {
      return firstName.toString();
    }

    // Extract username from email (part before @)
    final email = user!['email'];
    if (email != null && email.toString().contains('@')) {
      return email.toString().split('@').first;
    }

    // Fallback to full email or default
    return email?.toString() ?? 'LazyStrava Legend';
  }
}

/// Service class for making API requests to the backend
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// HTTP client for making requests
  final http.Client _client;

  /// Gets the base URL from environment variables
  /// Throws ApiException if BASE_URL is not configured
  String get _baseUrl {
    final value = dotenv.env['BASE_URL'];
    if (value == null || value.isEmpty) {
      throw ApiException('BASE_URL missing from .env');
    }
    // Remove trailing slash if present
    return value.toString().trim().replaceAll(RegExp(r'/$'), '');
  }

  /// Builds a complete URI from a path
  /// Ensures the path starts with a forward slash
  Uri _buildUri(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$cleanPath');
  }

  /// Default HTTP headers for API requests
  Map<String, String> get _defaultHeaders => const {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  /// Registers a new user with the API
  ///
  /// Throws [ApiException] if registration fails or network error occurs
  Future<void> registerUser({
    required String userName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String profileImageUrl = '',
  }) async {
    try {
      final response = await _client
          .post(
            _buildUri('/api/Users/register'),
            headers: _defaultHeaders,
            body: jsonEncode({
              'userName': userName,
              'firstName': firstName,
              'lastName': lastName,
              'email': email,
              'password': password,
              'profileImageUrl': profileImageUrl,
            }),
          )
          .timeout(
            const Duration(seconds: 300),
            onTimeout: () {
              throw ApiException(
                'Request timeout - please check your internet connection',
              );
            },
          );

      if (response.statusCode != 201) {
        throw ApiException(
          _extractErrorMessage(response.body),
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      throw ApiException(
        'Network error: Unable to connect to server. Please check:\n'
        '1. Your internet connection\n'
        '2. That the server is running and accessible\n'
        '3. Your BASE_URL in .env is correct\n'
        '4. macOS network permissions\n\n'
        'Details: ${e.message}',
      );
    } on http.ClientException catch (e) {
      final message = e.message;
      if (message.contains('Operation not permitted') ||
          message.contains('errno = 1')) {
        throw ApiException(
          'Network permission error: macOS is blocking the connection.\n\n'
          'Please check macOS network permissions in System Settings.',
        );
      }
      throw ApiException('Connection error: $message');
    } on HttpException catch (e) {
      throw ApiException('HTTP error: ${e.message}');
    } on FormatException catch (e) {
      throw ApiException('Invalid response format: ${e.message}');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }

  /// Logs in a user with email and password
  ///
  /// Returns [LoginResult] on success
  /// Throws [ApiException] if login fails or network error occurs
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client
          .post(
            _buildUri('/api/Users/login'),
            headers: _defaultHeaders,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw ApiException(
                'Request timeout - please check your internet connection',
              );
            },
          );

      if (response.statusCode != 200) {
        throw ApiException(
          _extractErrorMessage(response.body),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return LoginResult(
        raw: decoded,
        token: decoded['token'] as String?,
        user: decoded['user'] is Map<String, dynamic>
            ? decoded['user'] as Map<String, dynamic>
            : null,
        message: decoded['message'] as String?,
      );
    } on SocketException catch (e) {
      throw ApiException(
        'Network error: Unable to connect to server. Please check:\n'
        '1. Your internet connection\n'
        '2. That the server is running and accessible\n'
        '3. Your BASE_URL in .env is correct\n'
        '4. macOS network permissions (System Settings > Privacy & Security > Network)\n\n'
        'Error details: ${e.message}\n'
        'Address: ${e.address}\n'
        'Port: ${e.port}',
      );
    } on http.ClientException catch (e) {
      // ClientException wraps SocketException and other network errors
      final message = e.message;
      if (message.contains('Operation not permitted') ||
          message.contains('errno = 1')) {
        throw ApiException(
          'Network permission error: macOS is blocking the connection.\n\n'
          'Please check:\n'
          '1. System Settings > Privacy & Security > Network - allow your app\n'
          '2. Firewall settings - ensure the app can make outbound connections\n'
          '3. Try running the app from Terminal to see detailed error messages\n\n'
          'Original error: $message',
        );
      }
      throw ApiException(
        'Connection error: $message\n\n'
        'Please check your internet connection and that the server is accessible.',
      );
    } on HttpException catch (e) {
      throw ApiException('HTTP error: ${e.message}');
    } on FormatException catch (e) {
      throw ApiException('Invalid response format: ${e.message}');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }

  /// Extracts error message from API response body
  /// Tries to parse JSON and extract 'message' field, falls back to raw body
  String _extractErrorMessage(String body) {
    if (body.isEmpty) return 'Unknown error';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
      return decoded.toString();
    } catch (_) {
      return body;
    }
  }
}
