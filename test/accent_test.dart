import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrobr/core/accent.dart';

void main() {
  tearDown(() {
    applyAccent(defaultAccentId);
    applySolidAccent(null);
  });

  test('gold preset uses the logo colours', () {
    final gold = accentById('gold');
    expect(gold.primary, const Color(0xFFFFD559));
    expect(gold.solid, const Color(0xFFC99A16));
    expect(gold.gradientEnd, const Color(0xFFFF5959));
    applyAccent('gold');
    expect(kAccent, gold.primary);
    expect(kAccentGradient.colors, [gold.primary, gold.gradientEnd]);
  });

  test('unknown accent falls back to blue', () {
    applyAccent('missing');
    expect(activeAccent.id, defaultAccentId);
  });

  test('solid accent can follow or override the gradient preset', () {
    applyAccent('gold');
    applySolidAccent(null);
    expect(kAccentSolid, const Color(0xFFC99A16));

    applySolidAccent('violet');
    expect(kAccentSolid, const Color(0xFF7C3AED));

    applySolidAccent(null);
    expect(kAccentSolid, const Color(0xFFC99A16));
  });
}
