import 'package:intl/intl.dart';

String? asString(dynamic v) => v == null ? null : v.toString();

int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return v?.toString().toLowerCase() == 'true';
}

Map<String, dynamic> asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMaps(dynamic v) {
  if (v is! Iterable) return const [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

List<String> asStrings(dynamic v) {
  if (v is! Iterable) return const [];
  return v.where((e) => e != null).map((e) => e.toString()).toList();
}

extension JsonMapX on Map<String, dynamic> {
  String? s(String key) => asString(this[key]);
  int? i(String key) => asInt(this[key]);
  double? d(String key) => asDouble(this[key]);
  bool b(String key) => asBool(this[key]);
  List<Map<String, dynamic>> maps(String key) => asMaps(this[key]);
  List<String> strings(String key) => asStrings(this[key]);
  Map<String, dynamic> map(String key) => asMap(this[key]);
}

String fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return 'Unknown';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('d MMM yyyy').format(d);
}

String fmtDateTime(String? iso, {bool use24h = false}) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat(use24h ? 'd MMM yyyy, HH:mm' : 'd MMM yyyy, h:mm a').format(d);
}

String fmtDay(DateTime d) => DateFormat('EEE, d MMM').format(d);

String fmtRuntime(int? minutes) {
  if (minutes == null || minutes <= 0) return '';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String fmtMinutes(int? minutes) {
  if (minutes == null || minutes <= 0) return '0m';
  if (minutes < 120) return '${minutes}m';
  final h = minutes / 60;
  if (h < 100) return '${h.toStringAsFixed(h < 10 ? 1 : 0)}h';
  return '${NumberFormat.decimalPattern().format(minutes ~/ 60)}h';
}

String fmtCount(num? n) =>
    n == null ? '0' : NumberFormat.decimalPattern().format(n);

String fmtRating(num? n) {
  if (n == null || n <= 0) return '';
  return n.toStringAsFixed(1);
}

String fmtPercent(num? n) => '${(n ?? 0).round()}%';

String yearOf(dynamic date) {
  final s = asString(date);
  if (s == null || s.length < 4) return '';
  return s.substring(0, 4);
}

String initials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String truncate(String? text, int max) {
  if (text == null) return '';
  if (text.length <= max) return text;
  return '${text.substring(0, max).trimRight()}…';
}
