import 'dart:async';

import 'package:flutter/material.dart';

import '../app/ui_routes.dart';
import '../theme/ui_tokens.dart';

class BrandSplashScreen extends StatefulWidget {
  const BrandSplashScreen({super.key});

  @override
  State<BrandSplashScreen> createState() => _BrandSplashScreenState();
}

class _BrandSplashScreenState extends State<BrandSplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait for 1.8 seconds, then navigate to the loader.
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, UiRoutes.loader);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Scaffold(
      backgroundColor: ui.colors.background,
      body: Center(
        child: Text(
          'Luxis Games',
          style: ui.text.display.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
