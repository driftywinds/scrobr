import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Two-level (memory + disk) cache for authenticated poster/backdrop images.
///
/// `Image.network` only keeps decoded images in memory, so every cold start
/// re-downloaded every poster. Because the Scrob image proxy needs an
/// `Authorization` header we can't use the stock `cached_network_image`
/// without extra plumbing, so this is a deliberately small implementation on
/// top of `http` and `path_provider` (both already dependencies).
///
/// Cache keys are the URL only; credentials are never part of the key or the
/// file name.
class DiskImageCache {
  DiskImageCache({
    http.Client? client,
    Future<Directory?> Function()? directoryProvider,
    this.maxMemoryBytes = 24 * 1024 * 1024,
    this.maxDiskBytes = 200 * 1024 * 1024,
    this.maxAge = const Duration(days: 30),
    this.requestTimeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _directoryProvider = directoryProvider ?? _defaultDirectory;

  static final DiskImageCache instance = DiskImageCache();

  final http.Client _client;
  final Future<Directory?> Function() _directoryProvider;
  final int maxMemoryBytes;
  final int maxDiskBytes;
  final Duration maxAge;
  final Duration requestTimeout;

  final LinkedHashMap<String, Uint8List> _memory =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List>> _inflight = {};
  int _memoryBytes = 0;
  Future<Directory?>? _dirFuture;

  static Future<Directory?> _defaultDirectory() async {
    try {
      final base = await getTemporaryDirectory();
      final dir = Directory('${base.path}/scrobr_images');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      // No platform channel (unit tests) or no writable cache dir: fall back
      // to memory-only caching.
      return null;
    }
  }

  Future<Directory?> _ensureDir() {
    return _dirFuture ??= () async {
      final dir = await _directoryProvider();
      if (dir != null) unawaited(_prune(dir));
      return dir;
    }();
  }

  /// Synchronous memory lookup, so a widget can render a cached image on its
  /// very first frame without a placeholder flash.
  Uint8List? peek(String url) {
    final bytes = _memory.remove(url);
    if (bytes == null) return null;
    _memory[url] = bytes; // mark as most recently used
    return bytes;
  }

  /// Returns the image bytes from memory, disk or network (in that order).
  /// Concurrent requests for the same URL share one download.
  Future<Uint8List> load(
    String url, {
    Map<String, String>? headers,
    String? fallbackUrl,
  }) {
    final hit = peek(url);
    if (hit != null) return Future.value(hit);
    final running = _inflight[url];
    if (running != null) return running;
    final future = _resolve(url, headers, fallbackUrl).whenComplete(
      () => _inflight.remove(url),
    );
    _inflight[url] = future;
    return future;
  }

  Future<Uint8List> _resolve(
    String url,
    Map<String, String>? headers,
    String? fallbackUrl,
  ) async {
    final dir = await _ensureDir();
    final file = dir == null ? null : File('${dir.path}/${fileKey(url)}');

    if (file != null) {
      try {
        if (await file.exists()) {
          final age = DateTime.now().difference(await file.lastModified());
          if (age <= maxAge) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) {
              _remember(url, bytes);
              return bytes;
            }
          }
        }
      } catch (_) {
        // Unreadable cache entry: fall through to the network.
      }
    }

    Uint8List bytes;
    try {
      bytes = await _download(url, headers);
    } catch (_) {
      if (fallbackUrl == null) rethrow;
      // Posters are public artwork, so the unauthenticated URL is safe.
      bytes = await _download(fallbackUrl, null);
    }

    _remember(url, bytes);
    if (file != null) unawaited(_store(file, bytes));
    return bytes;
  }

  Future<Uint8List> _download(String url, Map<String, String>? headers) async {
    final response = await _client
        .get(Uri.parse(url), headers: headers)
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    if (response.bodyBytes.isEmpty) {
      throw HttpException('Empty image body', uri: Uri.parse(url));
    }
    return response.bodyBytes;
  }

  Future<void> _store(File file, Uint8List bytes) async {
    try {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } catch (_) {
      // Disk cache is best effort.
    }
  }

  void _remember(String url, Uint8List bytes) {
    final old = _memory.remove(url);
    if (old != null) _memoryBytes -= old.length;
    // Don't let one huge image flush everything else.
    if (bytes.length > maxMemoryBytes ~/ 4) return;
    _memory[url] = bytes;
    _memoryBytes += bytes.length;
    while (_memoryBytes > maxMemoryBytes && _memory.isNotEmpty) {
      final oldest = _memory.keys.first;
      _memoryBytes -= _memory.remove(oldest)!.length;
    }
  }

  /// Drops expired files, then the oldest ones until under [maxDiskBytes].
  Future<void> _prune(Directory dir) async {
    try {
      final entries = <({File file, int size, DateTime modified})>[];
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (entity.path.endsWith('.tmp')) {
          await entity.delete();
          continue;
        }
        if (DateTime.now().difference(stat.modified) > maxAge) {
          await entity.delete();
          continue;
        }
        entries.add((file: entity, size: stat.size, modified: stat.modified));
        total += stat.size;
      }
      if (total <= maxDiskBytes) return;
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      for (final entry in entries) {
        if (total <= maxDiskBytes) break;
        await entry.file.delete();
        total -= entry.size;
      }
    } catch (_) {
      // Pruning is best effort.
    }
  }

  /// Clears memory and disk. Used by "clear image cache" in settings.
  Future<void> clear() async {
    _memory.clear();
    _memoryBytes = 0;
    final dir = await _ensureDir();
    if (dir == null) return;
    try {
      await for (final entity in dir.list()) {
        if (entity is File) await entity.delete();
      }
    } catch (_) {}
  }

  /// Total bytes currently on disk (for the settings screen).
  Future<int> diskUsage() async {
    final dir = await _ensureDir();
    if (dir == null) return 0;
    var total = 0;
    try {
      await for (final entity in dir.list()) {
        if (entity is File) total += await entity.length();
      }
    } catch (_) {}
    return total;
  }

  /// Stable, filesystem-safe name for a URL (two 32-bit FNV-1a hashes).
  static String fileKey(String url) {
    var a = 0x811c9dc5;
    var b = 0x01000193 ^ 0x9e3779b9;
    for (final unit in url.codeUnits) {
      a = ((a ^ unit) * 0x01000193) & 0xFFFFFFFF;
      b = ((b ^ unit) * 0x85ebca6b) & 0xFFFFFFFF;
    }
    return '${a.toRadixString(16).padLeft(8, '0')}'
        '${b.toRadixString(16).padLeft(8, '0')}';
  }
}
