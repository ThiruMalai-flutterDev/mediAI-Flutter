import 'package:shared_preferences/shared_preferences.dart';

/// Storage service for managing local data persistence
class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;

  // Private constructor
  StorageService._();

  /// Get singleton instance of StorageService
  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Storage keys
  static const String _userTokenKey = 'user_auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _lastLoginKey = 'last_login';

  /// Save user authentication token
  Future<void> saveUserToken(String token) async {
    await _prefs?.setString(_userTokenKey, token);
    await _prefs?.setBool(_isLoggedInKey, true);
  }

  /// Get user authentication token
  String? getUserToken() {
    return _prefs?.getString(_userTokenKey);
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    await _prefs?.setString(_refreshTokenKey, token);
  }

  /// Get refresh token
  String? getRefreshToken() {
    return _prefs?.getString(_refreshTokenKey);
  }

  /// Save user ID
  Future<void> saveUserId(String userId) async {
    await _prefs?.setString(_userIdKey, userId);
  }

  /// Get user ID
  String? getUserId() {
    return _prefs?.getString(_userIdKey);
  }

  /// Save user email
  Future<void> saveUserEmail(String email) async {
    await _prefs?.setString(_userEmailKey, email);
  }

  /// Get user email
  String? getUserEmail() {
    return _prefs?.getString(_userEmailKey);
  }

  /// Save user name
  Future<void> saveUserName(String name) async {
    await _prefs?.setString(_userNameKey, name);
  }

  /// Get user name
  String? getUserName() {
    return _prefs?.getString(_userNameKey);
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _prefs?.getBool(_isLoggedInKey) ?? false;
  }

  /// Save last login timestamp
  Future<void> saveLastLogin() async {
    await _prefs?.setInt(_lastLoginKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get last login timestamp
  DateTime? getLastLogin() {
    final timestamp = _prefs?.getInt(_lastLoginKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  /// Save user data
  Future<void> saveUserData({
    required String token,
    required String userId,
    required String email,
    required String name,
    String? refreshToken,
  }) async {
    await Future.wait([
      saveUserToken(token),
      saveUserId(userId),
      saveUserEmail(email),
      saveUserName(name),
      if (refreshToken != null) saveRefreshToken(refreshToken),
      saveLastLogin(),
    ]);
  }

  /// Clear all user data (logout)
  Future<void> clearUserData() async {
    await Future.wait([
      _prefs?.remove(_userTokenKey) ?? Future.value(false),
      _prefs?.remove(_refreshTokenKey) ?? Future.value(false),
      _prefs?.remove(_userIdKey) ?? Future.value(false),
      _prefs?.remove(_userEmailKey) ?? Future.value(false),
      _prefs?.remove(_userNameKey) ?? Future.value(false),
      _prefs?.setBool(_isLoggedInKey, false) ?? Future.value(false),
    ]);
  }

  /// Clear specific data
  Future<void> clearData(String key) async {
    await _prefs?.remove(key);
  }

  /// Save generic string data
  Future<void> saveString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  /// Get generic string data
  String? getString(String key) {
    return _prefs?.getString(key);
  }

  /// Save generic boolean data
  Future<void> saveBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  /// Get generic boolean data
  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  /// Save generic integer data
  Future<void> saveInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  /// Get generic integer data
  int getInt(String key, {int defaultValue = 0}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  /// Save generic double data
  Future<void> saveDouble(String key, double value) async {
    await _prefs?.setDouble(key, value);
  }

  /// Get generic double data
  double getDouble(String key, {double defaultValue = 0.0}) {
    return _prefs?.getDouble(key) ?? defaultValue;
  }

  /// Save generic string list data
  Future<void> saveStringList(String key, List<String> value) async {
    await _prefs?.setStringList(key, value);
  }

  /// Get generic string list data
  List<String> getStringList(String key, {List<String> defaultValue = const []}) {
    return _prefs?.getStringList(key) ?? defaultValue;
  }

  /// Check if key exists
  bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  /// Get all keys
  Set<String> getKeys() {
    return _prefs?.getKeys() ?? {};
  }

  /// Remove specific key
  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  /// Clear all data
  Future<void> clear() async {
    await _prefs?.clear();
  }
}
