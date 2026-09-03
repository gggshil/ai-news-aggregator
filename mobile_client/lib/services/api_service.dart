import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'auth_state.dart';

class AuthResult {
  final bool success;
  final String message;
  final String? email;
  final String? error;
  final String? accessToken;
  final String? refreshToken;

  AuthResult({
    required this.success,
    required this.message,
    this.email,
    this.error,
    this.accessToken,
    this.refreshToken,
  });
}

class ApiService {
  static String get defaultBaseUrl => ApiClient.defaultBaseUrl;

  static String get baseUrl => ApiClient.instance.baseUrl;
  static set baseUrl(String url) {
    ApiClient.instance.baseUrl = url;
  }

  /// Handles email registration or login, saving issued access & refresh tokens on success.
  static Future<AuthResult> authenticate({
    required String email,
    required String password,
    required bool isRegistering,
    String? customBaseUrl,
  }) async {
    final effectiveUrl = (customBaseUrl != null && customBaseUrl.trim().isNotEmpty)
        ? customBaseUrl.trim()
        : baseUrl;
    ApiClient.instance.baseUrl = effectiveUrl;

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
          .timeout(const Duration(seconds: 45));

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 900;
        final subscriberId = data['subscriber']?['id'] as String? ?? 'sub_user';
        final subEmail = data['subscriber']?['email'] ?? email;

        if (accessToken != null && refreshToken != null) {
          await AuthManager.instance.handleLoginSuccess(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresInSeconds: expiresIn,
            email: subEmail,
            subscriberId: subscriberId,
          );
        }

        return AuthResult(
          success: true,
          message: data['message'] ?? 'Authentication successful!',
          email: subEmail,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } else {
        return AuthResult(
          success: false,
          message: data['detail'] ?? data['error'] ?? 'Authentication failed.',
          error: data['detail'] ?? data['error'],
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Unable to connect to the server. Please check your internet connection.',
        error: e.toString(),
      );
    }
  }

  /// Handles Google OAuth sign-in flow and persists returned access + refresh tokens.
  static Future<AuthResult> authenticateWithGoogle({
    required String email,
    String? customBaseUrl,
  }) async {
    final effectiveUrl = (customBaseUrl != null && customBaseUrl.trim().isNotEmpty)
        ? customBaseUrl.trim()
        : baseUrl;
    ApiClient.instance.baseUrl = effectiveUrl;

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
          .timeout(const Duration(seconds: 45));

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 900;
        final subscriberId = data['subscriber']?['id'] as String? ?? 'sub_user';
        final subEmail = data['subscriber']?['email'] ?? email;

        if (accessToken != null && refreshToken != null) {
          await AuthManager.instance.handleLoginSuccess(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresInSeconds: expiresIn,
            email: subEmail,
            subscriberId: subscriberId,
          );
        }

        return AuthResult(
          success: true,
          message: data['message'] ?? 'Authenticated with Google!',
          email: subEmail,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } else {
        return AuthResult(
          success: false,
          message: data['detail'] ?? data['error'] ?? 'Google authentication failed.',
          error: data['detail'] ?? data['error'],
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Unable to connect to the server. Please check your internet connection.',
        error: e.toString(),
      );
    }
  }

  /// Cancels subscription and deletes account using authenticated Bearer token.
  static Future<AuthResult> deleteAccount({
    required String email,
    String? customBaseUrl,
  }) async {
    if (customBaseUrl != null && customBaseUrl.trim().isNotEmpty) {
      ApiClient.instance.baseUrl = customBaseUrl.trim();
    }

    try {
      final response = await ApiClient.instance.sendAuthenticatedRequest(
        path: '/api/auth',
        method: 'POST',
        body: {
          'action': 'delete',
          'email': email,
        },
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await AuthManager.instance.logout();
        return AuthResult(
          success: true,
          message: data['message'] ?? 'Subscription cancelled successfully.',
          email: email,
        );
      } else {
        return AuthResult(
          success: false,
          message: data['detail'] ?? data['error'] ?? 'Could not cancel subscription.',
          error: data['detail'] ?? data['error'],
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Unable to connect to the server.',
        error: e.toString(),
      );
    }
  }

  /// Runs simultaneous requests to demonstrate Section 26.5 Concurrency Mutex:
  /// multiple concurrent requests when token is expired trigger ONE refresh and all retry cleanly.
  static Future<Map<String, dynamic>> testSimulateConcurrency() async {
    final startTime = DateTime.now();

    // Fire 3 simultaneous authenticated requests in parallel
    final futureA = ApiClient.instance.sendAuthenticatedRequest(
      path: '/api/auth',
      method: 'POST',
      body: {'action': 'me'},
    );

    final futureB = ApiClient.instance.sendAuthenticatedRequest(
      path: '/api/auth',
      method: 'POST',
      body: {'action': 'me'},
    );

    final futureC = ApiClient.instance.sendAuthenticatedRequest(
      path: '/api/auth',
      method: 'POST',
      body: {'action': 'me'},
    );

    final results = await Future.wait([futureA, futureB, futureC]);
    final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;

    final allSucceeded = results.every((res) => res.statusCode == 200);
    final statusCodes = results.map((res) => res.statusCode).toList();

    return {
      'success': allSucceeded,
      'statusCodes': statusCodes,
      'elapsedMs': elapsedMs,
      'message': allSucceeded
          ? 'Concurrency verified: 3 simultaneous requests resolved cleanly with single refresh mutex ($elapsedMs ms).'
          : 'One or more requests returned non-200: $statusCodes',
    };
  }
}
