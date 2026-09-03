import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyExpiresAtMs = 'auth_expires_at_ms';
  static const String _keyEmail = 'auth_subscriber_email';
  static const String _keySubscriberId = 'auth_subscriber_id';

  /// Saves session tokens and user metadata to persistent storage.
  static Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int expiresInSeconds,
    required String email,
    required String subscriberId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAtMs = DateTime.now().millisecondsSinceEpoch + (expiresInSeconds * 1000);

    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setInt(_keyExpiresAtMs, expiresAtMs);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keySubscriberId, subscriberId);
  }

  /// Updates just the access and refresh tokens (e.g. after token refresh/rotation).
  static Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresInSeconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAtMs = DateTime.now().millisecondsSinceEpoch + (expiresInSeconds * 1000);

    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setInt(_keyExpiresAtMs, expiresAtMs);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  static Future<String?> getSubscriberId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySubscriberId);
  }

  static Future<int?> getExpiresAtMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyExpiresAtMs);
  }

  /// Checks whether the access token is expired or will expire within [bufferSeconds].
  static Future<bool> isAccessTokenExpired({int bufferSeconds = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyAccessToken);
    if (token == null || token.isEmpty) return true;

    final expiresAtMs = prefs.getInt(_keyExpiresAtMs);
    if (expiresAtMs == null) return true;

    final nowWithBuffer = DateTime.now().millisecondsSinceEpoch + (bufferSeconds * 1000);
    return nowWithBuffer >= expiresAtMs;
  }

  static Future<bool> hasRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyRefreshToken);
    return token != null && token.isNotEmpty;
  }

  /// Clears all session credentials safely.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyExpiresAtMs);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keySubscriberId);
  }
}
