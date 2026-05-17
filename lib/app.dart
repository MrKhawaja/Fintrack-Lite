import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

class FinTrackApp extends ConsumerWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'FinTrack Lite',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    // Use dynamic ColorScheme on Android 12+ via platform contrast level
    // Fall back to seed color for other platforms
    final isAndroid = Platform.isAndroid;

    ColorScheme colorScheme;
    if (isAndroid && brightness == Brightness.light) {
      colorScheme = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.light,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      );
    } else if (isAndroid && brightness == Brightness.dark) {
      colorScheme = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      );
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: brightness,
      );
    }

    final baseTextTheme = brightness == Brightness.light
        ? GoogleFonts.interTextTheme()
        : GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: baseTextTheme,
    );
  }
}
