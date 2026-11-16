import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/accounts.dart';

void main() {
  test('saved accounts round-trip through JSON', () {
    final accounts = [
      const SavedAccount(
        server: 'https://one.test',
        name: 'One',
        userId: 1,
        token: 'token-1',
        avatarUrl: '/profile/avatar/1',
      ),
      const SavedAccount(
        server: 'https://two.test',
        name: 'Two',
        apiKey: 'api-key-2',
      ),
    ];

    final decoded = SavedAccount.decode(SavedAccount.encode(accounts));

    expect(decoded, hasLength(2));
    expect(decoded[0].server, 'https://one.test');
    expect(decoded[0].userId, 1);
    expect(decoded[0].token, 'token-1');
    expect(decoded[1].apiKey, 'api-key-2');
  });

  test('account identity prefers the user id and falls back to credentials', () {
    const user = SavedAccount(
      server: 'https://one.test',
      name: 'One',
      userId: 7,
      token: 'token',
    );
    const apiKey = SavedAccount(
      server: 'https://one.test',
      name: 'API key',
      apiKey: 'key',
    );

    expect(user.key, 'https://one.test|7');
    expect(apiKey.key, 'https://one.test|key');
  });

  test('malformed account data is ignored', () {
    expect(SavedAccount.decode('not json'), isEmpty);
    expect(
      SavedAccount.decode('[{"server": "", "name": "Bad"}]'),
      isEmpty,
    );
  });
}
