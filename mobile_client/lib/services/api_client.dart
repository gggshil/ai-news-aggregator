import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';
import 'auth_state.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  static ApiClient get instance => _instance;

  ApiClient._internal();

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ai-news-aggregator-nsqm.onrender.com',
  );

  String baseUrl = defaultBaseUrl;

  // Concurrency lock for token refresh
  Completer<bool>? _refreshCompleter;

  /// Centralized authenticated request dispatcher with automatic 401 interceptor,
  /// concurrency queue, and infinite-loop protection.
  Future<http.Response> sendAuthenticatedRequest({
    required String path,
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
    bool isRetry = false,
  }) async {
    final effectiveHeaders = Map<String, String>.from(headers ?? {});
    effectiveHeaders['Content-Type'] = 'application/json';

    // 1. Proactive Refresh: Check if token is expired or about to expire before dispatching
    if (!isRetry) {
      final isExpired = await AuthStorage.isAccessTokenExpired(bufferSeconds: 30);
      if (isExpired && await AuthStorage.hasRefreshToken()) {
        final refreshed = await refreshSessionToken();
        if (!refreshed) {
          // Refresh failed
          AuthManager.instance.markSessionExpired();
          return http.Response(
            jsonEncode({'detail': 'Your session has expired. Please sign in again.'}),
            401,
          );
        }
      }
    }

    // 2. Attach Bearer token
    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      effectiveHeaders['Authorization'] = 'Bearer $accessToken';
    }

    final uri = Uri.parse('$baseUrl$path');
    http.Response response;

    try {
      if (method.toUpperCase() == 'POST') {
        response = await http
            .post(
              uri,
              headers: effectiveHeaders,
              body: body is String ? body : (body != null ? jsonEncode(body) : null),
            )
            .timeout(const Duration(seconds: 45));
      } else if (method.toUpperCase() == 'DELETE') {
        response = await http
            .delete(
              uri,
              headers: effectiveHeaders,
              body: body is String ? body : (body != null ? jsonEncode(body) : null),
            )
            .timeout(const Duration(seconds: 45));
      } else {
        response = await http
            .get(uri, headers: effectiveHeaders)
            .timeout(const Duration(seconds: 45));
      }
    } catch (e) {
      return http.Response(
        jsonEncode({'detail': 'Network connection error: ${e.toString()}'}),
        503,
      );
    }

    // 3. Handle 401 Unauthorized
    if (response.statusCode == 401) {
      // Infinite Loop Protection: If this request was ALREADY retried once, do not refresh again!
      if (isRetry) {
        AuthManager.instance.markSessionExpired();
        return response;
      }

      // Check if we have a refresh token to attempt recovery
      final hasRefresh = await AuthStorage.hasRefreshToken();
      if (!hasRefresh) {
        AuthManager.instance.markSessionExpired();
        return response;
      }

      // Concurrency lock: exactly ONE refresh executes; concurrent requests await the same Future
      final refreshSuccess = await refreshSessionToken();

      if (refreshSuccess) {
        // Retry the original request ONCE with new access token
        return sendAuthenticatedRequest(
          path: path,
          method: method,
          headers: headers,
          body: body,
          isRetry: true,
        );
      } else {
        // Refresh failed: session is genuine invalid / expired
        AuthManager.instance.markSessionExpired();
        return response;
      }
    }

    return response;
  }

  /// Thread-safe / asynchronous concurrency mutex for token refresh.
  /// If multiple requests trigger this concurrently, only ONE network call is executed.
  Future<bool> refreshSessionToken() async {
    // If a refresh is already in flight, wait for it
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();
    AuthManager.instance.notifyRefreshing(true);

    try {
      final refreshToken = await AuthStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final uri = Uri.parse('$baseUrl/api/auth');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'refresh',
              'refresh_token': refreshToken,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 900;

        if (newAccessToken != null && newRefreshToken != null) {
          await AuthStorage.updateTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
            expiresInSeconds: expiresIn,
          );
          _refreshCompleter!.complete(true);
          return true;
        }
      }

      // Server rejected refresh (revoked or expired)
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      // Network or parsing error during refresh
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(false);
      }
      return false;
    } finally {
      AuthManager.instance.notifyRefreshing(false);
      _refreshCompleter = null;
    }
  }
}
