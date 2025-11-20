import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class LoginResult {
  LoginResult({required this.raw, this.token, this.user, this.message});

  final Map<String, dynamic> raw;
  final String? token;
  final Map<String, dynamic>? user;
  final String? message;

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

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl {
    final value = dotenv.env['BASE_URL'];
    if (value == null || value.isEmpty) {
      throw ApiException('BASE_URL missing from .env');
    }
    return value;
  }

  Uri _buildUri(String path) => Uri.parse('$_baseUrl$path');

  Map<String, String> get _defaultHeaders => const {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  Future<void> registerUser({
    required String userName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String profileImageUrl = '',
  }) async {
    final response = await _client.post(
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
    );

    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(response.body),
        statusCode: response.statusCode,
      );
    }
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _buildUri('/api/Users/login'),
      headers: _defaultHeaders,
      body: jsonEncode({'email': email, 'password': password}),
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
  }

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
