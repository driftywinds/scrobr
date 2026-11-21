import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/home_shortcuts.dart';
import '../core/theme.dart';

class HomeShortcutsScreen extends StatelessWidget {
  const HomeShortcutsScreen({super.key});

  Future<void> _save(
    AppState app,
    List<String> order,
    Set<String> hidden,
  ) =>
      app.saveHomeShortcuts(order, hidden);

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home shortcuts'),
        actions: [
          TextButton(
            onPressed: () => _save(
              app,
              [...defaultHomeShortcutIds],
              <String>{},
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Text(
              'Drag to reorder. Turn a shortcut off to hide it. Remaining '
              'shortcuts expand to fill the row; hiding all of them removes '
              'the row.',
              style: TextStyle(fontSize: 12, color: kMuted, height: 1.4),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: app.homeShortcutOrder.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final order = [...app.homeShortcutOrder];
                final id = order.removeAt(oldIndex);
                order.insert(newIndex, id);
                _save(app, order, app.hiddenHomeShortcuts);
              },
              itemBuilder: (context, index) {
                final id = app.homeShortcutOrder[index];
                final visible = !app.hiddenHomeShortcuts.contains(id);
                return ListTile(
                  key: ValueKey(id),
                  title: Text(homeShortcutLabel(id)),
                  subtitle: Text(visible ? 'Shown on Home' : 'Hidden'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: visible,
                        onChanged: (on) {
                          final hidden = {...app.hiddenHomeShortcuts};
                          if (on) {
                            hidden.remove(id);
                          } else {
                            hidden.add(id);
                          }
                          _save(app, app.homeShortcutOrder, hidden);
                        },
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.drag_handle_rounded),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
