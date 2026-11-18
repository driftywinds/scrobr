import 'package:material_ui/material_ui.dart';

import 'accent.dart';
export 'accent.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const kBg = Color(0xFF09090B);
const kSurface = Color(0xFF18181B);
const kCard = Color(0xFF27272A);
const kMuted = Color(0xFFB4B4BD);
const kAmber = Color(0xFFFBBF24);
const kDanger = Color(0xFFEF4444);
const kGreen = Color(0xFF22C55E);
const kBorder = Color(0xFF2E2E33);
const kBorderStrong = Color(0xFF3F3F46);
const kText = Color(0xFFF4F4F5);
const kBody = Color(0xFFD4D4D8);

// ── Shape & spacing tokens ─────────────────────────────────────────────────
const kRadiusSm = 8.0;
const kRadius = 12.0;
const kRadiusLg = 16.0;
const kPagePad = 16.0;

/// Subtle raised-surface decoration shared by cards, panels and tiles.
BoxDecoration panelDecoration({
  double radius = kRadius,
  Color color = kSurface,
  bool border = true,
}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ? Border.all(color: kBorder) : null,
    );

ThemeData buildTheme({String? fontFamily}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: kAccentSolid,
    onPrimary: kAccentSolidOn,
    secondary: kAccentSoft,
    surface: kBg,
    onSurface: Colors.white,
    surfaceContainerHighest: kSurface,
    error: kDanger,
    // SnackBar's fallback content colour derives from onInverseSurface.
    onInverseSurface: Colors.white,
  );

  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final textTheme = base.textTheme
      .copyWith(
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: kText,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: kText,
        ),
        bodyMedium: const TextStyle(height: 1.4, color: kText),
      )
      .apply(
        fontFamily: fontFamily,
        bodyColor: kText,
        displayColor: kText,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: Colors.white,
      ),
    ),
    cardColor: kSurface,
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: kBorder),
      ),
    ),
    dividerColor: kBorderStrong,
    dividerTheme: const DividerThemeData(color: kBorder, thickness: 1, space: 1),
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: kMuted,
      indicatorColor: kAccentSolid,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: kBorder,
      labelStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: kMuted,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: kText),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 46),
        foregroundColor: kText,
        side: const BorderSide(color: kBorderStrong),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kAccentSoft,
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusSm),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? kAccentSolid : kSurface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? kAccentSolidOn
              : Colors.white,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: kBorderStrong)),
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: kAccentSolid.withValues(alpha: 0.22),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected) ? Colors.white : kMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? Colors.white : kMuted,
        ),
      ),
      height: 68,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(fontFamily: fontFamily, color: kMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: const BorderSide(color: kBorderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: kAccentSolid, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kCard,
      contentTextStyle: TextStyle(
        fontFamily: fontFamily,
        color: Colors.white,
        fontSize: 13,
      ),
      actionTextColor: kAccentSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: kBorderStrong),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: kBorder),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: kCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: kBorderStrong),
      ),
      textStyle: TextStyle(fontFamily: fontFamily, fontSize: 14, color: kText),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurface,
      selectedColor: kAccentSolid.withValues(alpha: 0.3),
      side: const BorderSide(color: kBorderStrong),
      labelStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : kMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? kAccentSolid : kCard,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: kAccentSolid,
      linearTrackColor: kCard,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusSm),
        border: Border.all(color: kBorderStrong),
      ),
      textStyle: TextStyle(
        fontFamily: fontFamily,
        color: Colors.white,
        fontSize: 12,
      ),
    ),
  );
}
