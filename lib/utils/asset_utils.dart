/// Utility class for managing asset paths
class AssetUtils {
  // Base paths
  static const String _imagesPath = 'assets/images/';
  static const String _iconsPath = 'assets/icons/';
  static const String _fontsPath = 'assets/fonts/';

  // Image assets
  static const String logo = '${_imagesPath}logo.png';
  static const String appLogo = '${_imagesPath}applogo.jpg';
  static const String background = '${_imagesPath}background.jpg';
  static const String placeholder = '${_imagesPath}placeholder.png';

  // Icon assets
  static const String googleIcon = '${_iconsPath}google.png';
  static const String facebookIcon = '${_iconsPath}facebook.png';
  static const String appleIcon = '${_iconsPath}apple.png';
  static const String stethoscopeIcon = '${_iconsPath}stethoscope.svg';
  static const String injectionIcon = '${_iconsPath}injection.svg';

  // Font assets
  static const String primaryFont = '${_fontsPath}primary_font.ttf';
  static const String secondaryFont = '${_fontsPath}secondary_font.ttf';

  /// Get image path by name
  static String getImagePath(String imageName) {
    return '$_imagesPath$imageName';
  }

  /// Get icon path by name
  static String getIconPath(String iconName) {
    return '$_iconsPath$iconName';
  }

  /// Get font path by name
  static String getFontPath(String fontName) {
    return '$_fontsPath$fontName';
  }
}
