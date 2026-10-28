import 'package:flutter/material.dart';

/// Common desktop theme for the Editor and Admin applications.
ThemeData createToolTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: const Color(0xFF0EA5E9),
  ),
);
