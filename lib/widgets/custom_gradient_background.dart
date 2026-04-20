import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Custom gradient background widget that matches the CSS gradient specification
class CustomGradientBackground extends StatelessWidget {
  final Widget child;

  const CustomGradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.gradientDecoration,
      child: Container(
        decoration: AppTheme.overlayGradientDecoration,
        child: child,
      ),
    );
  }
}
