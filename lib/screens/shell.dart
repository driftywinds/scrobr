import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import 'discover_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selected = 'home';
  final Set<String> _visited = {'home'};

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final tabs = <_ShellTab>[
      _ShellTab(
        'home',
        const HomeScreen(),
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
      ),
      _ShellTab(
        'discover',
        const DiscoverScreen(),
        const NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore_rounded),
          label: 'Discover',
        ),
      ),
      if (app.showLibraryTab)
        _ShellTab(
          'library',
          const LibraryScreen(),
          const NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library_rounded),
            label: 'Library',
          ),
        ),
      _ShellTab(
        'history',
        const HistoryScreen(),
        const NavigationDestination(
          icon: Icon(Icons.history_rounded),
          selectedIcon: Icon(Icons.history_toggle_off_rounded),
          label: 'History',
        ),
      ),
      _ShellTab(
        'profile',
        const ProfileScreen(),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ),
    ];

    var index = tabs.indexWhere((tab) => tab.key == _selected);
    if (index < 0) index = 0;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (final tab in tabs)
            _visited.contains(tab.key) ? tab.page : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: NavigationBar(
          selectedIndex: index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (value) => setState(() {
            _selected = tabs[value].key;
            _visited.add(_selected);
          }),
          destinations: [for (final tab in tabs) tab.destination],
        ),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab(this.key, this.page, this.destination);

  final String key;
  final Widget page;
  final NavigationDestination destination;
}
