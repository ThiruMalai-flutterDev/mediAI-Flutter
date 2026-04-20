import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// Utility class for responsive design using Sizer
class ResponsiveUtils {
  /// Get responsive width based on screen width
  static double getWidth(BuildContext context, double width) {
    return width.w;
  }

  /// Get responsive height based on screen height
  static double getHeight(BuildContext context, double height) {
    return height.h;
  }

  /// Get responsive font size
  static double getFontSize(BuildContext context, double fontSize) {
    return fontSize.sp;
  }

  /// Get responsive padding
  static EdgeInsets getPadding(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    if (all != null) {
      return EdgeInsets.all(all.w);
    }
    
    return EdgeInsets.only(
      top: (top ?? vertical ?? 0).h,
      bottom: (bottom ?? vertical ?? 0).h,
      left: (left ?? horizontal ?? 0).w,
      right: (right ?? horizontal ?? 0).w,
    );
  }

  /// Get responsive margin
  static EdgeInsets getMargin(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    if (all != null) {
      return EdgeInsets.all(all.w);
    }
    
    return EdgeInsets.only(
      top: (top ?? vertical ?? 0).h,
      bottom: (bottom ?? vertical ?? 0).h,
      left: (left ?? horizontal ?? 0).w,
      right: (right ?? horizontal ?? 0).w,
    );
  }

  /// Get responsive border radius
  static BorderRadius getBorderRadius(BuildContext context, double radius) {
    return BorderRadius.circular(radius.sp);
  }

  /// Check if screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Check if screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1024;
  }

  /// Check if screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  /// Check if screen is small tablet (7-8 inch)
  static bool isSmallTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 768;
  }

  /// Check if screen is large tablet (9+ inch)
  static bool isLargeTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 768 && width < 1024;
  }

  /// Get responsive column count for grid
  static int getGridColumnCount(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isSmallTablet(context)) return 2;
    if (isLargeTablet(context)) return 3;
    return 4;
  }

  /// Get responsive column count for book grid
  static int getBookGridColumnCount(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isSmallTablet(context)) return 2;
    if (isLargeTablet(context)) return 3;
    return 4;
  }

  /// Get responsive column count for chat messages
  static int getChatColumnCount(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 1; // Keep single column for chat
    return 1;
  }

  /// Get responsive max width for content
  static double getMaxContentWidth(BuildContext context) {
    if (isMobile(context)) return double.infinity;
    if (isSmallTablet(context)) return 500;
    if (isLargeTablet(context)) return 600;
    return 700;
  }

  /// Get responsive padding for screens
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h);
    } else if (isSmallTablet(context)) {
      return EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h);
    } else if (isLargeTablet(context)) {
      return EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h);
    } else {
      return EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h);
    }
  }

  /// Get responsive font size with better scaling
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    if (isMobile(context)) {
      return (baseFontSize * 1.2).sp; // Increase mobile font sizes by 20%
    } else if (isSmallTablet(context)) {
      return (baseFontSize * 1.1).sp;
    } else if (isLargeTablet(context)) {
      return (baseFontSize * 1.2).sp;
    } else {
      return (baseFontSize * 1.3).sp;
    }
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    if (isMobile(context)) {
      return (baseSize * 1.3).sp; // Increase mobile icon sizes by 30%
    } else if (isSmallTablet(context)) {
      return (baseSize * 1.2).sp;
    } else if (isLargeTablet(context)) {
      return (baseSize * 1.4).sp;
    } else {
      return (baseSize * 1.6).sp;
    }
  }

  /// Get responsive spacing
  static double getSpacing(BuildContext context, double spacing) {
    return spacing.w;
  }

  /// Get responsive icon size
  static double getIconSize(BuildContext context, double size) {
    return size.sp;
  }

  /// Get responsive elevation
  static double getElevation(BuildContext context, double elevation) {
    return elevation.sp;
  }
}
