import 'package:material_ui/material_ui.dart';

const defaultAccentId = 'blue';
const accentPrefKey = 'scrobr_accent';
const accentSolidPrefKey = 'scrobr_accent_solid';

class AccentPreset {
  const AccentPreset({
    required this.id,
    required this.name,
    required this.primary,
    required this.soft,
    required this.solid,
    required this.gradientEnd,
  });

  final String id;
  final String name;
  final Color primary;
  final Color soft;
  final Color solid;
  final Color gradientEnd;
}

const accentPresets = <AccentPreset>[
  AccentPreset(
    id: 'blue',
    name: 'Blue',
    primary: Color(0xFF3B82F6),
    soft: Color(0xFF60A5FA),
    solid: Color(0xFF2563EB),
    gradientEnd: Color(0xFF6366F1),
  ),
  AccentPreset(
    id: 'gold',
    name: 'Scrobr Gold',
    primary: Color(0xFFFFD559),
    soft: Color(0xFFFFE29A),
    solid: Color(0xFFC99A16),
    gradientEnd: Color(0xFFFF5959),
  ),
  AccentPreset(
    id: 'violet',
    name: 'Violet',
    primary: Color(0xFF8B5CF6),
    soft: Color(0xFFC4B5FD),
    solid: Color(0xFF7C3AED),
    gradientEnd: Color(0xFF6366F1),
  ),
  AccentPreset(
    id: 'green',
    name: 'Green',
    primary: Color(0xFF22C55E),
    soft: Color(0xFF86EFAC),
    solid: Color(0xFF16A34A),
    gradientEnd: Color(0xFF14B8A6),
  ),
  AccentPreset(
    id: 'rose',
    name: 'Rose',
    primary: Color(0xFFEC4899),
    soft: Color(0xFFF9A8D4),
    solid: Color(0xFFDB2777),
    gradientEnd: Color(0xFFF43F5E),
  ),
  AccentPreset(
    id: 'orange',
    name: 'Orange',
    primary: Color(0xFFF97316),
    soft: Color(0xFFFDBA74),
    solid: Color(0xFFEA580C),
    gradientEnd: Color(0xFFFBBF24),
  ),
];

AccentPreset activeAccent = accentPresets.first;
AccentPreset? activeSolidAccent;

Color get kAccent => activeAccent.primary;
Color get kAccentSoft => activeAccent.soft;
Color get kAccentSolid => (activeSolidAccent ?? activeAccent).solid;
Color get kAccentOn =>
    ThemeData.estimateBrightnessForColor(kAccent) == Brightness.dark
        ? Colors.black
        : Colors.white;
Color get kAccentSolidOn =>
    ThemeData.estimateBrightnessForColor(kAccentSolid) == Brightness.dark
        ? Colors.black
        : Colors.white;
LinearGradient get kAccentGradient => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [activeAccent.primary, activeAccent.gradientEnd],
    );

AccentPreset accentById(String? id) => accentPresets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => accentPresets.first,
    );

void applyAccent(String? id) {
  activeAccent = accentById(id);
}

void applySolidAccent(String? id) {
  activeSolidAccent = id == null ? null : accentById(id);
}
