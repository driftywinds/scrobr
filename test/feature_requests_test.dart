import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/admin_tools.dart';
import 'package:scrobr/core/device_auth.dart';
import 'package:scrobr/core/list_imports.dart';
import 'package:scrobr/core/season_collect.dart';
import 'package:scrobr/core/tracker_imports.dart';

void main() {
  group('season collect', () {
    test('builds collect body and uncollect query', () {
      expect(
        seasonCollectBody(seriesTmdbId: 10, seasonNumber: 2),
        {'series_tmdb_id': 10, 'season_number': 2},
      );
      expect(
        seasonCollectBody(
          seriesTmdbId: 10,
          seasonNumber: 2,
          episodeOrder: 'tvdb:official',
        )['episode_order'],
        'tvdb:official',
      );
      expect(
        seasonUncollectQuery(
          seriesTmdbId: 10,
          seasonNumber: 2,
          episodeOrder: '',
        ).containsKey('episode_order'),
        isFalse,
      );
    });
  });

  group('list imports', () {
    test('covers all four supported sources', () {
      expect(
        listImportSources.map((e) => e.path),
        [
          '/lists/import/tmdb',
          '/lists/import/tvdb',
          '/lists/import/imdb',
          '/lists/import/mdblist',
        ],
      );
    });

    test('trims the input and extracts job state', () {
      expect(
        listImportBody('  https://www.themoviedb.org/list/123  '),
        {'list_id_or_url': 'https://www.themoviedb.org/list/123'},
      );
      expect(
        listImportJobId({
          'import': {'id': 'job-1', 'status': 'running'},
        }),
        'job-1',
      );
      expect(listImportJobId({'import': {}}), isNull);
      expect(listImportFinished({'status': 'completed'}), isTrue);
      expect(listImportFinished({'status': 'failed'}), isTrue);
      expect(listImportFinished({'status': 'running'}), isFalse);
      expect(
        listImportSummary({'status': 'completed', 'added': 4, 'skipped': 1}),
        'Imported 4 item(s), skipped 1',
      );
    });
  });

  group('device approval', () {
    test('normalizes human-entered codes', () {
      expect(normalizeDeviceCode(' ab-cd 12 '), 'ABCD12');
    });

    test('builds approve and deny payloads', () {
      expect(
        deviceApproveBody(userCode: ' ab-cd ', approve: true),
        {'user_code': 'ABCD', 'action': 'approve'},
      );
      expect(
        deviceApproveBody(
          userCode: 'ABCD',
          approve: false,
          name: '  Phone  ',
        ),
        {'user_code': 'ABCD', 'action': 'deny', 'name': 'Phone'},
      );
    });
  });

  group('tracker imports and admin helpers', () {
    test('uses the documented upload paths and fields', () {
      expect(traktImportPath, '/trakt/import/upload');
      expect(yamtrackImportPath, '/yamtrack/import/upload');
      expect(bingebasePushPath, '/bingebase/push');
      expect(traktImportFields['sync_lists'], 'true');
      expect(yamtrackImportFields['collection'], 'true');
    });

    test('trims API test keys and includes optional PIN', () {
      expect(apiKeyTestBody(' key '), {'key': 'key'});
      expect(
        apiKeyTestBody('key', pin: ' 123 '),
        {'key': 'key', 'pin': '123'},
      );
    });
  });
}
