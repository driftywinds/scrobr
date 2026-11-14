import 'package:material_ui/material_ui.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(ScrobApp(state: state));
}

class ScrobApp extends StatelessWidget {
  const ScrobApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ScrobScope(
      notifier: state,
      child: MaterialApp(
        title: 'Scrob',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: ListenableBuilder(
          listenable: state,
          builder: (context, _) =>
              state.isLoggedIn ? const AppShell() : const LoginScreen(),
        ),
      ),
    );
  }
}
