/// API Response model for handling server responses
class ApiResponse {
  final String? version;
  final dynamic validationErrors;
  final int code;
  final bool status;
  final String message;
  final dynamic data;

  ApiResponse({
    this.version,
    this.validationErrors,
    required this.code,
    required this.status,
    required this.message,
    this.data,
  });

  /// Check if the response is successful
  bool get isSuccess => code == 200 && status;

  /// Check if the response has validation errors
  bool get hasValidationErrors => validationErrors != null;

  /// Get validation errors as a list of strings
  List<String> get validationErrorsList {
    if (validationErrors == null) return [];
    
    if (validationErrors is List) {
      return validationErrors.cast<String>();
    }
    
    if (validationErrors is Map) {
      final List<String> errors = [];
      validationErrors.forEach((key, value) {
        if (value is Map && value.containsKey('_errors')) {
          final List<dynamic> errorList = value['_errors'] ?? [];
          errors.addAll(errorList.map((e) => e.toString()));
        } else if (value is String) {
          errors.add(value);
        }
      });
      return errors;
    }
    
    return [validationErrors.toString()];
  }

  /// Create a copy of this response with updated values
  ApiResponse copyWith({
    String? version,
    dynamic validationErrors,
    int? code,
    bool? status,
    String? message,
    dynamic data,
  }) {
    return ApiResponse(
      version: version ?? this.version,
      validationErrors: validationErrors ?? this.validationErrors,
      code: code ?? this.code,
      status: status ?? this.status,
      message: message ?? this.message,
      data: data ?? this.data,
    );
  }

  @override
  String toString() {
    return 'ApiResponse(version: $version, validationErrors: $validationErrors, code: $code, status: $status, message: $message, data: $data)';
  }
}







