import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrobr/core/theme.dart';

void main() {
  testWidgets('snackbar content renders white on the dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('toast text')),
              ),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    final style = tester
        .widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.text('toast text'),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style;
    expect(style.color, Colors.white);
  });
}
