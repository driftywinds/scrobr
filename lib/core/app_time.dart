import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Display-time conversion for every server timestamp.
///
/// With no override we use the phone's current zone via [DateTime.toLocal],
/// so changing the device zone is reflected immediately. An override uses the
/// bundled IANA database and still handles daylight-saving transitions.
class AppTime {
  static bool _initialized = false;
  static String? _zoneId;

  static String? get zoneId => _zoneId;

  static String get label => _zoneId ?? 'Phone time zone';

  static void initialize(String? zoneId) {
    _zoneId = isValidZone(zoneId) ? zoneId : null;
  }

  static void ensureInitialized() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  static bool isValidZone(String? id) {
    if (id == null || id.isEmpty) return false;
    ensureInitialized();
    return tz.timeZoneDatabase.locations.containsKey(id);
  }

  static List<String> get zones {
    ensureInitialized();
    final names = tz.timeZoneDatabase.locations.keys.toList()..sort();
    return names;
  }

  static DateTime? parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    // Air dates and birthdays are calendar dates, not instants. Converting
    // those through a zone can move them to the previous/next day.
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(iso)) return parsed;
    return fromInstant(parsed);
  }

  static DateTime fromInstant(DateTime instant) {
    final id = _zoneId;
    if (id == null) return instant.toLocal();
    ensureInitialized();
    try {
      return tz.TZDateTime.from(instant.toUtc(), tz.getLocation(id));
    } catch (_) {
      return instant.toLocal();
    }
  }

  static DateTime now() {
    final id = _zoneId;
    if (id == null) return DateTime.now();
    ensureInitialized();
    try {
      return tz.TZDateTime.now(tz.getLocation(id));
    } catch (_) {
      return DateTime.now();
    }
  }
}
