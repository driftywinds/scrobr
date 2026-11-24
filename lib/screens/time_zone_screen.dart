import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/app_time.dart';
import '../core/theme.dart';

class TimeZoneScreen extends StatefulWidget {
  const TimeZoneScreen({super.key});

  @override
  State<TimeZoneScreen> createState() => _TimeZoneScreenState();
}

class _TimeZoneScreenState extends State<TimeZoneScreen> {
  final _search = TextEditingController();
  final _zones = AppTime.zones;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _zones
        : _zones.where((id) {
            final label = _label(id).toLowerCase();
            return id.toLowerCase().contains(query) || label.contains(query);
          }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Time zone')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search time zones',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Phone time zone follows the device automatically. Picking a '
                'zone only changes how Scrobr displays timestamps.',
                style: TextStyle(fontSize: 12, color: kMuted, height: 1.4),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: filtered.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.phone_android_rounded),
                    title: const Text('Phone time zone'),
                    subtitle: const Text('Use the device’s current zone'),
                    trailing: app.timeZoneId == null
                        ? const Icon(Icons.check_rounded, color: kGreen)
                        : null,
                    onTap: () async {
                      await app.setTimeZone(null);
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                }
                final id = filtered[index - 1];
                return ListTile(
                  title: Text(_label(id)),
                  subtitle: Text(id),
                  trailing: app.timeZoneId == id
                      ? const Icon(Icons.check_rounded, color: kGreen)
                      : null,
                  onTap: () async {
                    await app.setTimeZone(id);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _label(String id) => id.replaceAll('_', ' ');
}
