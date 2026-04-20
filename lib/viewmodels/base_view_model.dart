import 'package:flutter/foundation.dart';

/// Base view model class for all view models
abstract class BaseViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Getters
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;

  // Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error state
  void setError(String error) {
    _hasError = true;
    _errorMessage = error;
    notifyListeners();
  }

  // Clear error state
  void clearError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }

  // Override dispose to clean up resources
  @override
  void dispose() {
    super.dispose();
  }
}







