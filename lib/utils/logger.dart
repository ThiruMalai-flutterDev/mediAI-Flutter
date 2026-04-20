import 'package:logger/logger.dart';

/// Global logger instance
final Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2, // Number of method calls to be displayed
    errorMethodCount: 8, // Number of method calls if stacktrace is provided
    lineLength: 120, // Width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    printTime: true, // Should each log print contain a timestamp
  ),
);

/// Simple logger for basic logging needs
class AppLogger {
  static void d(String message) {
    logger.d(message);
  }

  static void i(String message) {
    logger.i(message);
  }

  static void w(String message) {
    logger.w(message);
  }

  static void e(String message) {
    logger.e(message);
  }

  static void f(String message) {
    logger.f(message);
  }

  static void v(String message) {
    logger.v(message);
  }
}







