import 'package:material_ui/material_ui.dart';

const defaultAccentId = 'blue';
const accentPrefKey = 'scrobr_accent';

class AccentPreset {
  const AccentPreset({
    required this.id,
    required this.name,
    required this.primary,
    required this.soft,
    required this.gradientEnd,
  });

  final String id;
  final String name;
  final Color primary;
  final Color soft;
  final Color gradientEnd;
}

const accentPresets = <AccentPreset>[
  AccentPreset(
    id: 'blue',
    name: 'Blue',
    primary: Color(0xFF3B82F6),
    soft: Color(0xFF60A5FA),
    gradientEnd: Color(0xFF6366F1),
  ),
  AccentPreset(
    id: 'gold',
    name: 'Scrobr Gold',
    primary: Color(0xFFFFD559),
    soft: Color(0xFFFFE29A),
    gradientEnd: Color(0xFFFF5959),
  ),
  AccentPreset(
    id: 'violet',
    name: 'Violet',
    primary: Color(0xFF8B5CF6),
    soft: Color(0xFFC4B5FD),
    gradientEnd: Color(0xFF6366F1),
  ),
  AccentPreset(
    id: 'green',
    name: 'Green',
    primary: Color(0xFF22C55E),
    soft: Color(0xFF86EFAC),
    gradientEnd: Color(0xFF14B8A6),
  ),
  AccentPreset(
    id: 'rose',
    name: 'Rose',
    primary: Color(0xFFEC4899),
    soft: Color(0xFFF9A8D4),
    gradientEnd: Color(0xFFF43F5E),
  ),
  AccentPreset(
    id: 'orange',
    name: 'Orange',
    primary: Color(0xFFF97316),
    soft: Color(0xFFFDBA74),
    gradientEnd: Color(0xFFFBBF24),
  ),
];

AccentPreset activeAccent = accentPresets.first;

Color get kAccent => activeAccent.primary;
Color get kAccentSoft => activeAccent.soft;
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
