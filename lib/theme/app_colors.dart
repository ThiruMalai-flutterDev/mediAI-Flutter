import 'package:flutter/material.dart';

/// App color constants
class AppColors {
  // Primary colors
  static const Color primaryPurple = Color(0xFF9D549D);
  static const Color secondaryPurple = Color(0xFF633E8C);
  static const Color baseGray = Color(0xFFD9D9D9);
  
  // Neutral colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mediumGray = Color(0xFF9CA3AF);
  static const Color darkGray = Color(0xFF666666);
  static const Color charcoal = Color(0xFF374151);
  
  // Status colors
  static const Color errorRed = Color(0xFFE53E3E);
  static const Color successGreen = Color(0xFF38A169);
  static const Color warningOrange = Color(0xFFDD6B20);
  static const Color infoBlue = Color(0xFF3182CE);
  
  // Social login colors
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color appleBlack = Color(0xFF000000);
  
  // Gradient colors
  static const List<Color> primaryGradient = [
    Color(0xFF9D549D), // #9D549D
    Color(0xFF633E8C), // #633E8C
  ];
  
  static const List<Color> baseGradient = [
    Color(0xFFD9D9D9), // #D9D9D9
    Color(0xFFD9D9D9), // #D9D9D9
  ];
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textDark = Color(0xFF000000);
  static const Color textHint = Color(0xFF6B7280);
  
  // Background colors
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color backgroundDark = Color(0xFF111827);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1F2937);
  
  // Border colors
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF374151);
  static const Color borderFocus = Color(0xFF9D549D);
  static const Color borderError = Color(0xFFE53E3E);
  
  // Shadow colors
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowDark = Color(0x4D000000);
  
  // Overlay colors
  static const Color overlayLight = Color(0x80000000);
  static const Color overlayDark = Color(0xCC000000);
  
  // Transparent colors
  static const Color transparent = Color(0x00000000);
  static const Color whiteTransparent = Color(0x80FFFFFF);
  static const Color blackTransparent = Color(0x80000000);
  
  // Get color by brightness
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? textPrimary 
        : textDark;
  }
  
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? backgroundDark 
        : backgroundLight;
  }
  
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? surfaceDark 
        : surfaceLight;
  }
  
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? borderDark 
        : borderLight;
  }
}







