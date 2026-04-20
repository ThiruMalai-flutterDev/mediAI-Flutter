import 'package:flutter/material.dart';
import 'responsive_utils.dart';

/// A widget that provides responsive design capabilities
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? smallTablet;
  final Widget? largeTablet;
  final Widget? tablet;
  final Widget? desktop;
  final Widget child;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.smallTablet,
    this.largeTablet,
    this.tablet,
    this.desktop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveUtils.isDesktop(context)) {
      return desktop ?? largeTablet ?? tablet ?? mobile;
    } else if (ResponsiveUtils.isLargeTablet(context)) {
      return largeTablet ?? tablet ?? mobile;
    } else if (ResponsiveUtils.isSmallTablet(context)) {
      return smallTablet ?? tablet ?? mobile;
    } else if (ResponsiveUtils.isTablet(context)) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }
}

/// A responsive container that adapts its properties based on screen size
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Decoration? decoration;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
    this.borderRadius,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width != null ? ResponsiveUtils.getWidth(context, width!) : null,
      height: height != null ? ResponsiveUtils.getHeight(context, height!) : null,
      padding: padding != null ? ResponsiveUtils.getPadding(context, all: padding!.left) : null,
      margin: margin != null ? ResponsiveUtils.getMargin(context, all: margin!.left) : null,
      decoration: decoration ??
          BoxDecoration(
            color: color,
            borderRadius: borderRadius != null
                ? ResponsiveUtils.getBorderRadius(context, borderRadius!)
                : null,
            boxShadow: boxShadow,
          ),
      child: child,
    );
  }
}

/// A responsive text widget that adapts font size based on screen size
class ResponsiveText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle? style;

  const ResponsiveText(
    this.text, {
    super.key,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style ??
          TextStyle(
            fontSize: fontSize != null ? ResponsiveUtils.getFontSize(context, fontSize!) : null,
            fontWeight: fontWeight,
            color: color,
          ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// A responsive button that adapts its size based on screen size
class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final double? fontSize;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Widget? child;

  const ResponsiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height,
    this.fontSize,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.borderRadius,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width != null ? ResponsiveUtils.getWidth(context, width!) : null,
      height: height != null ? ResponsiveUtils.getHeight(context, height!) : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          padding: padding != null
              ? ResponsiveUtils.getPadding(context, all: padding!.left)
              : null,
          shape: borderRadius != null
              ? RoundedRectangleBorder(
                  borderRadius: ResponsiveUtils.getBorderRadius(context, borderRadius!),
                )
              : null,
        ),
        child: child ??
            ResponsiveText(
              text,
              fontSize: fontSize,
              color: textColor,
            ),
      ),
    );
  }
}
