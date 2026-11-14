import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scrob/core/image_cache.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scrobr_cache_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  DiskImageCache makeCache(http.Client client) => DiskImageCache(
        client: client,
        directoryProvider: () async => dir,
      );

  test('downloads once, then serves from memory', () async {
    var calls = 0;
    final cache = makeCache(MockClient((request) async {
      calls++;
      expect(request.headers['Authorization'], 'Bearer t');
      return http.Response.bytes([1, 2, 3], 200);
    }));

    final first = await cache.load(
      'https://x.test/a.jpg',
      headers: {'Authorization': 'Bearer t'},
    );
    final second = await cache.load('https://x.test/a.jpg');

    expect(first, [1, 2, 3]);
    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(cache.peek('https://x.test/a.jpg'), isNotNull);
  });

  test('a second cache instance reads the file written by the first', () async {
    final first = makeCache(
      MockClient((_) async => http.Response.bytes([9, 9], 200)),
    );
    await first.load('https://x.test/b.jpg');
    // Let the fire-and-forget write finish.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    var calls = 0;
    final second = makeCache(MockClient((_) async {
      calls++;
      return http.Response.bytes([0], 200);
    }));
    final bytes = await second.load('https://x.test/b.jpg');

    expect(bytes, [9, 9]);
    expect(calls, 0);
  });

  test('concurrent loads of one URL share a single request', () async {
    var calls = 0;
    final cache = makeCache(MockClient((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response.bytes([7], 200);
    }));

    final results = await Future.wait([
      cache.load('https://x.test/c.jpg'),
      cache.load('https://x.test/c.jpg'),
      cache.load('https://x.test/c.jpg'),
    ]);

    expect(calls, 1);
    expect(results.every((b) => b.length == 1), isTrue);
  });

  test('falls back to the public URL without credentials', () async {
    final seen = <Uri>[];
    final cache = makeCache(MockClient((request) async {
      seen.add(request.url);
      if (request.url.host == 'own.test') {
        return http.Response('nope', 502);
      }
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response.bytes([4, 4], 200);
    }));

    final bytes = await cache.load(
      'https://own.test/api/proxy/media/image/w342/p.jpg',
      headers: {'Authorization': 'Bearer secret'},
      fallbackUrl: 'https://image.tmdb.org/t/p/w342/p.jpg',
    );

    expect(bytes, [4, 4]);
    expect(seen.map((u) => u.host), ['own.test', 'image.tmdb.org']);
  });

  test('failures throw and are not cached', () async {
    var calls = 0;
    final cache = makeCache(MockClient((_) async {
      calls++;
      return http.Response('boom', 500);
    }));

    await expectLater(cache.load('https://x.test/d.jpg'), throwsException);
    await expectLater(cache.load('https://x.test/d.jpg'), throwsException);
    expect(calls, 2);
    expect(cache.peek('https://x.test/d.jpg'), isNull);
  });

  test('memory cache evicts least recently used entries', () async {
    final cache = DiskImageCache(
      client: MockClient(
        (_) async => http.Response.bytes(Uint8List(40), 200),
      ),
      directoryProvider: () async => null,
      maxMemoryBytes: 100,
    );

    await cache.load('https://x.test/1');
    await cache.load('https://x.test/2');
    cache.peek('https://x.test/1'); // 1 is now newer than 2
    await cache.load('https://x.test/3');

    expect(cache.peek('https://x.test/2'), isNull);
    expect(cache.peek('https://x.test/1'), isNotNull);
    expect(cache.peek('https://x.test/3'), isNotNull);
  });

  test('file keys are stable, distinct and filesystem safe', () {
    final a = DiskImageCache.fileKey('https://x.test/a.jpg?v=1');
    expect(a, DiskImageCache.fileKey('https://x.test/a.jpg?v=1'));
    expect(a, isNot(DiskImageCache.fileKey('https://x.test/a.jpg?v=2')));
    expect(a, matches(RegExp(r'^[0-9a-f]{16}$')));
  });
}
