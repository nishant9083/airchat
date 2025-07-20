import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AirChatTheme {
  // Define the new core colors based on user's request
  static const Color _primaryColorBase = Color(0xFF1B3C53); // Deep, muted blue
  static const Color _secondaryColorBase = Color(0xFF456882); // Lighter, slightly greyish blue

    static const Color _primaryLightColorBase = Color(0xFF3A5A7A); // Lighter blue for light theme
  static const Color _secondaryLightColorBase = Color(0xFF7CA3C7);

  // Backgrounds and surfaces
  static const Color _lightScaffoldBackground = Color(0xFFF5F5F5); // Very light grey
  static const Color _darkScaffoldBackground = Color(0xFF1A2A3A); // Deep desaturated blue for dark mode background

  static const Color _lightSurface = Colors.white; // Pure white for cards, app bars
  static const Color _darkSurface = Color(0xFF2A4055); // Darker blue for cards, app bars in dark mode

  // Text colors
  static const Color _lightOnSurfaceText = Color(0xFF212121); // Dark grey for text on light surfaces
  static const Color _darkOnSurfaceText = Colors.white70; // Muted white for body text in dark mode
  static const Color _darkOnSurfaceTitle = Colors.white; // Pure white for titles in dark mode

  // Input field colors
  static const Color _lightInputFill = Color(0xFFEEEEEE); // Light grey for input fields
  static const Color _darkInputFill = Color(0xFF3A506B); // Darker blue for input fields in dark mode

  // Icon colors for theme - Adjusted for better matching
  static const Color _lightIconColor = _primaryColorBase; // Icons in light mode use primary color
  static const Color _darkIconColor = Colors.white; // Icons in dark mode are pure white for clarity

  // IconThemeData for light and dark
  static const IconThemeData lightIconTheme = IconThemeData(color: _lightIconColor, opacity: 1.0, size: 24);
  static const IconThemeData darkIconTheme = IconThemeData(color: _darkIconColor, opacity: 1.0, size: 24);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: _primaryLightColorBase, // Using the deep blue as primary
      scaffoldBackgroundColor: _lightScaffoldBackground,
      
      colorScheme: ColorScheme.light(
        primary: _primaryLightColorBase,
        secondary: _secondaryColorBase, // Using the lighter blue as secondary
        secondaryContainer: Colors.white,
        surface: _lightSurface,
        onSurfaceVariant: _lightScaffoldBackground,
        onPrimary: Colors.white, // White text on the dark primary blue
        onSecondary: Colors.white, // White text on the lighter secondary blue
        onSurface: _lightOnSurfaceText,        
        error: Colors.red,
        onError: Colors.white,
      ),

      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: _lightOnSurfaceText,
        displayColor: _lightOnSurfaceText,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        elevation: 1,
        iconTheme: lightIconTheme, // Use themed icon color
        titleTextStyle: TextStyle(
          color: _lightOnSurfaceText,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: _lightOnSurfaceText.withValues(alpha:0.6)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColorBase,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      cardTheme: CardTheme(
        color: _lightSurface,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha:0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryColorBase,
        foregroundColor: Colors.white,
      ),

      dividerColor: Colors.grey[300],
      iconTheme: lightIconTheme, // Set default icon theme for light mode
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _primaryColorBase,
      scaffoldBackgroundColor: _darkScaffoldBackground,

      colorScheme: ColorScheme.dark(
        primary: _primaryColorBase,
        secondary: _secondaryColorBase,
        secondaryContainer: _secondaryColorBase,
        onSurfaceVariant: _darkSurface,
        surface: _darkScaffoldBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _darkOnSurfaceText,        
        error: Colors.redAccent,
        onError: Colors.black,
      ),

      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: _darkOnSurfaceText,
        displayColor: _darkOnSurfaceTitle,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        elevation: 1,
        iconTheme: darkIconTheme, // Use themed icon color
        titleTextStyle: TextStyle(
          color: _darkOnSurfaceTitle,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: _darkOnSurfaceText.withValues(alpha:0.6)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColorBase,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      cardTheme: CardTheme(
        color: _darkSurface,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha:0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryColorBase,
        foregroundColor: Colors.white,
      ),

      dividerColor: Colors.grey[700],
      iconTheme: darkIconTheme, // Set default icon theme for dark mode      
    );
  }
}
