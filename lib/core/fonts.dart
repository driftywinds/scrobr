const kAlloFontFamily = 'Allo';

class AppFont {
  const AppFont({required this.id, required this.label, this.family});

  final String id;
  final String label;
  final String? family;
}

const appFonts = [
  AppFont(id: 'system', label: 'System'),
  AppFont(id: 'allo', label: 'Allo', family: kAlloFontFamily),
];

AppFont appFontById(String? id) {
  for (final font in appFonts) {
    if (font.id == id) return font;
  }
  return appFonts.first;
}
