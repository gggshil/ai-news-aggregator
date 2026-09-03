import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';
import 'api_client.dart';

enum AuthStatus {
  initializing,
  authenticated,
  unauthenticated,
  refreshing,
  sessionExpired,
  loggingOut,
}

class AuthManager extends ChangeNotifier {
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  static AuthManager get instance => _instance;

  AuthManager._internal() {
    _initCrossTabSync();
  }

  AuthStatus _status = AuthStatus.initializing;
  String? _userEmail;
  String? _errorMessage;
  bool _isRefreshing = false;
  Timer? _crossTabSyncTimer;

  AuthStatus get status => _status;
  String? get userEmail => _userEmail;
  String? get errorMessage => _errorMessage;
  bool get isRefreshing => _isRefreshing;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Restores session on app startup or browser refresh (F5).
  Future<void> restoreSession() async {
    _status = AuthStatus.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasRefresh = await AuthStorage.hasRefreshToken();
      if (!hasRefresh) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final email = await AuthStorage.getEmail();
      _userEmail = email;

      // Check if access token is still valid or refresh it
      final isExpired = await AuthStorage.isAccessTokenExpired(bufferSeconds: 30);
      if (isExpired) {
        final refreshOk = await ApiClient.instance.refreshSessionToken();
        if (!refreshOk) {
          markSessionExpired();
          return;
        }
      }

      // Verify session with the backend
      final response = await ApiClient.instance.sendAuthenticatedRequest(
        path: '/api/auth',
        method: 'POST',
        body: {'action': 'me'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _userEmail = data['subscriber']?['email'] ?? _userEmail;
        _status = AuthStatus.authenticated;
      } else {
        markSessionExpired();
      }
    } catch (e) {
      // If network fails during initial restoration but we have tokens, retain cached session
      final email = await AuthStorage.getEmail();
      if (email != null && email.isNotEmpty) {
        _userEmail = email;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } finally {
      notifyListeners();
    }
  }

  /// Sets authenticated state following a successful login or Google OAuth.
  Future<void> handleLoginSuccess({
    required String accessToken,
    required String refreshToken,
    required int expiresInSeconds,
    required String email,
    required String subscriberId,
  }) async {
    await AuthStorage.saveSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresInSeconds: expiresInSeconds,
      email: email,
      subscriberId: subscriberId,
    );

    _userEmail = email;
    _errorMessage = null;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// Terminates the authenticated session and notifies backend to revoke tokens.
  Future<void> logout() async {
    _status = AuthStatus.loggingOut;
    notifyListeners();

    try {
      final refreshToken = await AuthStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        // Fire-and-forget token revocation request
        final uri = Uri.parse('${ApiClient.instance.baseUrl}/api/auth');
        http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'logout',
            'refresh_token': refreshToken,
          }),
        ).timeout(const Duration(seconds: 5)).ignore();
      }
    } catch (_) {
      // Safe ignore
    } finally {
      await AuthStorage.clearSession();
      _userEmail = null;
      _errorMessage = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// Marks session as expired and shows friendly user message.
  void markSessionExpired() {
    AuthStorage.clearSession();
    _userEmail = null;
    _errorMessage = "Your session has expired. Please sign in again.";
    _status = AuthStatus.sessionExpired;
    notifyListeners();
  }

  void notifyRefreshing(bool refreshing) {
    if (_isRefreshing != refreshing) {
      _isRefreshing = refreshing;
      notifyListeners();
    }
  }

  /// Multi-tab session synchronization (periodically verifies token presence across tabs)
  void _initCrossTabSync() {
    if (kIsWeb) {
      _crossTabSyncTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (_status == AuthStatus.authenticated) {
          final hasToken = await AuthStorage.hasRefreshToken();
          if (!hasToken) {
            // Another tab logged out
            _status = AuthStatus.unauthenticated;
            _userEmail = null;
            notifyListeners();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _crossTabSyncTimer?.cancel();
    super.dispose();
  }
}
