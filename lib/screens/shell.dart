import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
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
        NavigationDestination(
          icon: _profileIcon(app),
          selectedIcon: _profileIcon(app, selected: true),
          label: 'Profile',
        ),
      ),
    ];

    var index = tabs.indexWhere((tab) => tab.key == _selected);
    if (index < 0) index = 0;

    return Scaffold(
      body: IndexedStack(
        key: ValueKey(app.currentAccountKey),
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

  Widget _profileIcon(AppState app, {bool selected = false}) {
    final avatar = app.me == null
        ? null
        : app.imageUrl(app.me?.s('avatar_url'));
    final picture = app.me == null
        ? Icon(selected ? Icons.person_rounded : Icons.person_outline_rounded)
        : UserAvatar(url: avatar, name: app.displayName, size: 26);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showAccounts(app),
      child: picture,
    );
  }

  Future<void> _showAccounts(AppState app) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Accounts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            for (final account in app.accounts)
              ListTile(
                leading: UserAvatar(
                  url: account.key == app.currentAccountKey
                      ? app.imageUrl(app.me?.s('avatar_url'))
                      : null,
                  name: account.name,
                  size: 38,
                ),
                title: Text(account.name),
                subtitle: Text(
                  Uri.tryParse(account.server)?.host ?? account.server,
                ),
                trailing: account.key == app.currentAccountKey
                    ? const Icon(Icons.check_rounded, color: kAccent)
                    : null,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await app.switchAccount(account);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not switch account: $e')),
                    );
                  }
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded, color: kAccent),
              title: const Text('Add account'),
              subtitle: const Text('Sign in to another Scrob account'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await app.addAccount();
              },
            ),
          ],
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
