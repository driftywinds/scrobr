import 'package:material_ui/material_ui.dart';

const kBg = Color(0xFF09090B);
const kSurface = Color(0xFF18181B);
const kCard = Color(0xFF27272A);
const kAccent = Color(0xFF3B82F6);
const kMuted = Color(0xFFB4B4BD);
const kAmber = Color(0xFFFBBF24);
const kDanger = Color(0xFFEF4444);
const kGreen = Color(0xFF22C55E);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: kAccent,
    secondary: const Color(0xFF60A5FA),
    surface: kBg,
    onSurface: Colors.white,
    surfaceContainerHighest: kSurface,
    error: kDanger,
    // SnackBar's fallback content colour derives from onInverseSurface.
    onInverseSurface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
    cardColor: kSurface,
    dividerColor: const Color(0xFF3F3F46),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? kAccent : kSurface,
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Color(0xFF3F3F46)),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kAccent.withValues(alpha: 0.22),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      height: 66,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3F3F46)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kCard,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
      actionTextColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurface,
      selectedColor: kAccent.withValues(alpha: 0.3),
      side: const BorderSide(color: Color(0xFF3F3F46)),
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
