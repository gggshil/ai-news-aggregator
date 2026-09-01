import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthResult {
  final bool success;
  final String message;
  final String? email;
  final String? error;

  AuthResult({
    required this.success,
    required this.message,
    this.email,
    this.error,
  });
}

class ApiService {
  // Default URL points to local dev server (port 8000) or your deployed Vercel URL
  static String baseUrl = 'http://localhost:8000';

  static Future<AuthResult> authenticate({
    required String email,
    required String password,
    required bool isRegistering,
    String? customBaseUrl,
  }) async {
    final effectiveUrl = customBaseUrl ?? baseUrl;
    final uri = Uri.parse('$effectiveUrl/api/auth');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': isRegistering ? 'register' : 'login',
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult(
          success: true,
          message: data['message'] ?? 'Success!',
          email: data['subscriber']?['email'] ?? email,
        );
      } else {
        return AuthResult(
          success: false,
          message: data['error'] ?? 'Authentication failed.',
          error: data['error'],
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Could not connect to backend server: $e',
        error: e.toString(),
      );
    }
  }

  static Future<AuthResult> authenticateWithGoogle({
    required String email,
    String? customBaseUrl,
  }) async {
    final effectiveUrl = customBaseUrl ?? baseUrl;
    final uri = Uri.parse('$effectiveUrl/api/auth');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'google_signin',
              'email': email,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult(
          success: true,
          message: data['message'] ?? 'Authenticated with Google!',
          email: data['subscriber']?['email'] ?? email,
        );
      } else {
        return AuthResult(
          success: false,
          message: data['error'] ?? 'Google authentication failed.',
          error: data['error'],
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Could not connect to backend server: $e',
        error: e.toString(),
      );
    }
  }
}

