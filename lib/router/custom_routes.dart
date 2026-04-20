import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import 'package:dr_jebasingh_onco_ai/screens/chat_screen.dart';
import 'package:dr_jebasingh_onco_ai/screens/login_screen.dart';
import 'package:dr_jebasingh_onco_ai/screens/splash_screen.dart';

class CustomRoutes {
  static const Transition _defaultTransition = Transition.leftToRightWithFade;
  static const Duration _defaultDuration = Duration(milliseconds: 500);

  static Future<T?> routeToNext<T>(
    Widget page, {
    Transition transition = _defaultTransition,
    Duration duration = _defaultDuration,
    bool preventDuplicates = true,
    Object? arguments,
  }) {
    return Get.to<T>(
      () => page,
      transition: transition,
      duration: duration,
      preventDuplicates: preventDuplicates,
      arguments: arguments,
    ) ?? Future.value(null);
  }

  static Future<T?> routeToNextAndClear<T>(
    Widget page, {
    Transition transition = _defaultTransition,
    Duration duration = _defaultDuration,
    Object? arguments,
  }) {
    return Get.offAll<T>(
      () => page,
      transition: transition,
      duration: duration,
      arguments: arguments,
    ) ?? Future.value(null);
  }

  static Future<T?> routeToNextAndReplace<T>(
    Widget page, {
    Transition transition = _defaultTransition,
    Duration duration = _defaultDuration,
    Object? arguments,
  }) {
    return Get.off<T>(
      () => page,
      transition: transition,
      duration: duration,
      arguments: arguments,
    ) ?? Future.value(null);
  }

  static void goBack<T>({
    T? result,
    bool closeOverlays = false,
  }) {
    Get.back<T>(
      result: result,
      closeOverlays: closeOverlays,
    );
  }

  static void goBackTo(String routeName) {
    Get.until((route) => route.settings.name == routeName);
  }

  static void goBackWithTransition<T>({
    T? result,
    Transition transition = _defaultTransition,
    Duration duration = _defaultDuration,
    bool closeOverlays = false,
  }) {
    Get.back<T>(
      result: result,
      closeOverlays: closeOverlays,
    );
  }

  /// Fixed navigation methods:

  static Future<void> toSplashScreen(BuildContext context) {
    return Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SplashScreen(),
        transitionDuration: const Duration(seconds: 1),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  static Future<void> toLoginScreen(BuildContext context) {
    return Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionDuration: const Duration(seconds: 1),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  static Future<void> toLoginScreenReplace(BuildContext context) {
    return Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionDuration: const Duration(seconds: 1),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  static Future<void> toChatScreen(BuildContext context) {
    return Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ChatScreen(),
        transitionDuration: const Duration(seconds: 2),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
      (route) => false,
    );
  }

  static Future<void> toChatScreenReplace(BuildContext context) {
    return Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ChatScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  static void showLoadingDialog({
    String title = 'Loading...',
    String message = 'Please wait',
  }) {
    Get.dialog(
      AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(title),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  static void hideLoadingDialog() {
    if (Get.isDialogOpen == true) {
      Get.back();
    }
  }

  static Future<T?> showBottomSheet<T>(
    Widget child, {
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
  }) {
    return Get.bottomSheet<T>(
      child,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
    );
  }

  static void showSnackBar({
    required String title,
    required String message,
    SnackPosition position = SnackPosition.BOTTOM,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    Color? colorText,
    Widget? icon,
    bool shouldIconPulse = true,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: position,
      duration: duration,
      backgroundColor: backgroundColor,
      colorText: colorText,
      icon: icon,
      shouldIconPulse: shouldIconPulse,
    );
  }

  static void showSuccessSnackBar({
    required String message,
    String title = 'Success',
  }) {
    showSnackBar(
      title: title,
      message: message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }

  static void showErrorSnackBar({
    required String message,
    String title = 'Error',
  }) {
    showSnackBar(
      title: title,
      message: message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      icon: const Icon(Icons.error, color: Colors.white),
    );
  }

  static void showWarningSnackBar({
    required String message,
    String title = 'Warning',
  }) {
    showSnackBar(
      title: title,
      message: message,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      icon: const Icon(Icons.warning, color: Colors.white),
    );
  }
}
