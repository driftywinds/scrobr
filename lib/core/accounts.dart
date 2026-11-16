import 'dart:convert';

const accountsKey = 'scrobr_accounts';

class SavedAccount {
  const SavedAccount({
    required this.server,
    required this.name,
    this.userId,
    this.token,
    this.apiKey,
    this.avatarUrl,
  });

  final String server;
  final String name;
  final int? userId;
  final String? token;
  final String? apiKey;
  final String? avatarUrl;

  String get key => userId == null
      ? '$server|${apiKey ?? token ?? name}'
      : '$server|$userId';

  Map<String, dynamic> toJson() => {
        'server': server,
        'name': name,
        if (userId != null) 'user_id': userId,
        if (token != null) 'token': token,
        if (apiKey != null) 'api_key': apiKey,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

  static SavedAccount? fromJson(Object? value) {
    if (value is! Map) return null;
    final server = value['server'];
    final name = value['name'];
    if (server is! String || server.isEmpty || name is! String) return null;
    return SavedAccount(
      server: server,
      name: name,
      userId: value['user_id'] is int ? value['user_id'] as int : null,
      token: value['token'] is String ? value['token'] as String : null,
      apiKey: value['api_key'] is String ? value['api_key'] as String : null,
      avatarUrl:
          value['avatar_url'] is String ? value['avatar_url'] as String : null,
    );
  }

  static List<SavedAccount> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return const [];
      return value
          .map(SavedAccount.fromJson)
          .whereType<SavedAccount>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String encode(List<SavedAccount> accounts) =>
      jsonEncode([for (final account in accounts) account.toJson()]);
}
