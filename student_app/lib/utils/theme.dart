import 'package:flutter/material.dart';

class AppTheme {
  // ============ GOVERNMENT THEME COLORS ============
  // Primary Colors - Government Theme
  static const Color primaryBlue = Color(0xFF1E3A8A); // Navy Blue - Government
  static const Color primaryDark = Color(0xFF0F172A); // Dark Navy
  static const Color accentGold = Color(
    0xFFFBBF24,
  ); // Gold/Yellow - Tanzania Flag

  // Secondary Colors
  static const Color primaryGreen = Color(
    0xFF10B981,
  ); // Green - Success/Accepted
  static const Color error = Color(0xFFEF4444); // Red - Error/Rejected
  static const Color warning = Color(0xFFF59E0B); // Orange - Pending/Warning
  static const Color info = Color(0xFF3B82F6); // Light Blue - Shortlisted/Info
  static const Color accentOrange = Color(0xFFF59E0B); // Orange - Accent

  // Status Colors
  static const Color pending = Color(0xFFF59E0B); // Orange
  static const Color shortlisted = Color(0xFF3B82F6); // Blue
  static const Color interview = Color(0xFF8B5CF6); // Purple
  static const Color accepted = Color(0xFF10B981); // Green
  static const Color rejected = Color(0xFFEF4444); // Red

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF6F8FB);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textDark = Color(0xFF1F2937); // Alias for textPrimary
  static const Color borderGrey = Color(0xFFD7E1EA); // Border color
  static const Color surfaceSoft = Color(0xFFF9FBFC);
  static const Color shadow = Color(0xFF0F172A);

  // ============ GRADIENTS ============
  static const LinearGradient tanzaniaGradient = LinearGradient(
    colors: [primaryBlue, primaryGreen, accentGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient governmentGradient = LinearGradient(
    colors: [primaryBlue, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [primaryGreen, Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============ TEXT STYLES ============
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyText = TextStyle(fontSize: 14, color: textPrimary);

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: textSecondary,
  );

  // ============ BOX DECORATIONS ============
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: shadow.withValues(alpha: 0.06),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
    border: Border.all(color: borderGrey.withValues(alpha: 0.45)),
  );

  static OutlineInputBorder inputBorder({
    Color? color,
    double width = 1,
    double radius = 14,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(
        color: color ?? borderGrey.withValues(alpha: 0.6),
        width: width,
      ),
    );
  }

  static BoxDecoration searchBarDecoration = BoxDecoration(
    color: white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: shadow.withValues(alpha: 0.05),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
    border: Border.all(color: borderGrey.withValues(alpha: 0.35)),
  );

  static BoxDecoration goldAccentDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: [accentGold, Color(0xFFFCD34D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(12),
  );
}
