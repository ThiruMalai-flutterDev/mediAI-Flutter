import 'base_view_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/url_services.dart';
import '../utils/logger.dart';

class LoginViewModel extends BaseViewModel {
  String _username = '';
  String _password = '';

  // Getters
  String get username => _username;
  String get password => _password;

  // Set user credentials
  void setCredentials(String username, String password) {
    _username = username;
    _password = password;
    notifyListeners();
  }

  /// Login with username and password
  Future<void> login(String username, String password,
      {bool rememberMe = false}) async {
    setLoading(true);
    clearError();
    setCredentials(username, password);

    // Check internet connectivity first
    final hasInternet = await ApiService.hasInternetConnection();
    if (!hasInternet) {
      setError(
          'No internet connection. Please check your network settings and try again.');
      setLoading(false);
      return;
    }

    // Retry mechanism for server errors
    int retryCount = 0;
    const maxRetries = 2;

    // List of login endpoints to try (in order of preference)
    final loginEndpoints = [
      UrlServices.LOGIN, // /api/api/login (primary)
      UrlServices.LOGIN_ALT, // /api/login (fallback)
      UrlServices.LOGIN_AUTH, // /auth/login (fallback)
      UrlServices.LOGIN_V1, // /api/v1/login (fallback)
    ];

    while (retryCount <= maxRetries) {
      for (final endpoint in loginEndpoints) {
        try {
          logger.i('Trying login endpoint: $endpoint');
          final response = await ApiService.post(
            endpoint: endpoint,
            json: {
              'username': username,
              'password': password,
            },
          );

          if (response.isSuccess) {
            // Store user data
            final storage = await StorageService.getInstance();

            // Extract user data from response
            String responseUsername = username; // fallback to input username
            String? responseEmail;
            String? responseMobileNumber;
            String? responseToken;
            String? responseUserId;
            bool? isPasswordSet;
            int? role;

            if (response.data != null &&
                response.data is Map<String, dynamic>) {
              final responseData = response.data as Map<String, dynamic>;
              responseUsername = responseData['username'] ?? username;
              responseEmail = responseData['email'];
              responseMobileNumber = responseData['mobileNumber']?.toString();
              responseToken = responseData['token'];
              responseUserId = responseData['userId']?.toString();
              isPasswordSet = responseData['isPasswordSet'];
              role = responseData['role'];
            }

            // Save all user data
            await storage.saveUserName(responseUsername);
            if (responseEmail != null) {
              await storage.saveUserEmail(responseEmail);
            }
            if (responseMobileNumber != null) {
              await storage.saveString('mobileNumber', responseMobileNumber);
            }
            if (responseToken != null) {
              await storage.saveUserToken(responseToken);
            }
            if (responseUserId != null) {
              await storage.saveUserId(responseUserId);
            }
            if (isPasswordSet != null) {
              await storage.saveBool('isPasswordSet', isPasswordSet);
            }
            if (role != null) {
              await storage.saveInt('role', role);
            }

            // Save remember me preference
            await storage.saveBool('remember_me', rememberMe);

            logger.i('Login successful with endpoint: $endpoint');
            logger.i(
                'User data saved - Username: $responseUsername, Email: $responseEmail, Mobile: $responseMobileNumber');
            setLoading(false);
            return; // Success, exit completely
          } else if (response.code == 404) {
            // If 404, try next endpoint
            logger.w('Endpoint $endpoint not found (404), trying next...');
            continue;
          } else {
            // For authentication errors (400, 401, 403), don't retry - show server message
            if (response.code == 400 ||
                response.code == 401 ||
                response.code == 403 ||
                response.code == 422) {
              setError(response.message);
              setLoading(false);
              return; // Exit completely
            }
            // For 500 errors with authentication messages, don't retry - show server message
            else if (response.code == 500 &&
                (response.message.toLowerCase().contains('invalid') ||
                    response.message.toLowerCase().contains('password') ||
                    response.message.toLowerCase().contains('credential') ||
                    response.message
                        .toLowerCase()
                        .contains('authentication'))) {
              setError(response.message);
              setLoading(false);
              return; // Exit completely
            }
            // For other server errors (500+), check if we should retry
            else if (response.code >= 500 && retryCount < maxRetries) {
              retryCount++;
              logger.w(
                  'Server error ${response.code} on $endpoint, retrying... (attempt $retryCount/$maxRetries)');
              await Future.delayed(
                  Duration(seconds: retryCount * 2)); // Exponential backoff
              break; // Break out of endpoint loop to retry
            } else {
              setError(response.message);
              setLoading(false);
              return; // Exit completely
            }
          }
        } catch (e) {
          logger.w('Error with endpoint $endpoint: $e');
          if (endpoint == loginEndpoints.last) {
            // This was the last endpoint, check if we should retry
            if (retryCount < maxRetries) {
              retryCount++;
              logger.w(
                  'All endpoints failed, retrying... (attempt $retryCount/$maxRetries)');
              await Future.delayed(
                  Duration(seconds: retryCount * 2)); // Exponential backoff
              break; // Break out of endpoint loop to retry
            } else {
              setError(
                  'Login failed: All endpoints unavailable. Please check your internet connection and try again.');
              logger.e('Login error: $e');
              setLoading(false);
              return; // Exit completely
            }
          }
          // Continue to next endpoint
        }
      }

      // If we get here, all endpoints failed and we're not retrying
      if (retryCount >= maxRetries) {
        setError(
            'Login failed: Unable to connect to server. Please check your internet connection and try again.');
        break;
      }
    }

    setLoading(false);
  }

  /// Login with Google (placeholder)
  Future<void> loginWithGoogle() async {
    setLoading(true);
    clearError();

    try {
      // TODO: Implement Google Sign-In
      await Future.delayed(const Duration(seconds: 2));

      // Simulate success
      setCredentials('google_user@example.com', 'google_password');
      logger.i('Google login successful');
    } catch (e) {
      setError('Google login failed: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  /// Login with Facebook (placeholder)
  Future<void> loginWithFacebook() async {
    setLoading(true);
    clearError();

    try {
      // TODO: Implement Facebook Sign-In
      await Future.delayed(const Duration(seconds: 2));

      // Simulate success
      setCredentials('facebook_user@example.com', 'facebook_password');
      logger.i('Facebook login successful');
    } catch (e) {
      setError('Facebook login failed: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  /// Check for saved credentials and auto-login
  Future<bool> checkAutoLogin() async {
    try {
      final storage = await StorageService.getInstance();
      final rememberMe = storage.getBool('remember_me');
      final isLoggedIn = storage.isLoggedIn();
      final userToken = storage.getUserToken();

      if (rememberMe &&
          isLoggedIn &&
          userToken != null &&
          userToken.isNotEmpty) {
        final username = storage.getUserName() ?? '';

        if (username.isNotEmpty) {
          // User is already logged in and remember me is enabled
          logger
              .i('Auto-login successful: User $username is already logged in');

          // Set the credentials in the view model for consistency
          setCredentials(username, '');

          return true;
        } else {
          logger.w('Auto-login failed: Missing username');
          // Clear invalid data
          await storage.clearUserData();
        }
      } else {
        if (!rememberMe) {
          logger.i('Auto-login disabled: Remember me is false');
        } else if (!isLoggedIn) {
          logger.i('Auto-login disabled: User is not logged in');
        } else if (userToken == null || userToken.isEmpty) {
          logger.i('Auto-login disabled: No valid token found');
        }
      }
      return false;
    } catch (e) {
      logger.e('Auto-login error: $e');
      return false;
    }
  }

  /// Clear invalid credentials (for debugging)
  Future<void> clearInvalidCredentials() async {
    try {
      final storage = await StorageService.getInstance();
      await storage.clearUserData();
      clearError();
      setCredentials('', '');
      logger.i('Invalid credentials cleared');
    } catch (e) {
      logger.e('Error clearing credentials: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      final storage = await StorageService.getInstance();

      // Clear all user data from storage
      await storage.clearUserData();

      // Clear local state
      clearError();
      setCredentials('', '');

      logger.i('Logout successful - All user data cleared');
    } catch (e) {
      logger.e('Error during logout: $e');
      // Even if there's an error, clear local state
      clearError();
      setCredentials('', '');
    }
  }
}
