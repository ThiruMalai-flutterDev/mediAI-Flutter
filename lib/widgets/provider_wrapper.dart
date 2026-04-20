import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';

/// Wrapper widget that ensures Provider context is always available
class ProviderWrapper extends StatelessWidget {
  final Widget child;

  const ProviderWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.allProviders,
      child: child,
    );
  }
}







