import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'format.dart';

const _kServer = 'scrobr_server';
const _kToken = 'scrob_token';
const _kApiKey = 'scrob_api_key';
const _kShowLibrary = 'scrobr_show_library';
const _kCalendarDays = 'scrobr_calendar_days';
const _kFollowingListId = 'scrobr_following_list_id';
const _kFollowingMirror = 'scrobr_following_mirror';
const kFollowingListName = 'Following · Calendar';
const _kFollowingMarker = 'Calendar follows created by Scrobr.';

class AppState extends ChangeNotifier {
  AppState({String? initialServer})
      : server = normalizeOrigin(initialServer ?? '');

  late SharedPreferences _prefs;
  ApiClient? _client;

  String server;
  String? token;
  String? apiKey;
  Map<String, dynamic>? me;
  Map<String, dynamic>? settings;
  bool initialized = false;
  bool showLibraryTab = false;
  int calendarDays = 21;
  String? sessionError;

  bool get hasServer => server.isNotEmpty;
  bool get isLoggedIn => token != null || apiKey != null;
  bool get isApiKeyMode => token == null && apiKey != null;
  bool get isAdmin => me?.b('is_admin') ?? false;
  int? get userId => me?.i('id');
  String get displayName =>
      me?.s('display_name') ?? me?.s('username') ?? (isApiKeyMode ? 'API key' : 'Scrob user');
  String get origin => server;
  String get proxyUrl => hasServer ? '$server/api/proxy' : '';

  ApiClient get client {
    if (!hasServer) {
      throw StateError('No Scrob server configured');
    }
    return _client ??= ApiClient(
      baseUrl: proxyUrl,
      token: token,
      apiKey: apiKey,
    );
  }

  static String normalizeOrigin(String value) {
    var s = value.trim();
    if (s.isEmpty) return '';
    final lower = s.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      s = 'https://$s';
    }
    s = s.replaceAll(RegExp(r'/+$'), '');
    if (s.endsWith('/api/proxy')) {
      s = s.substring(0, s.length - '/api/proxy'.length);
    }
    return s;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    server = normalizeOrigin(_prefs.getString(_kServer) ?? '');
    showLibraryTab = _prefs.getBool(_kShowLibrary) ?? false;
    calendarDays = ((_prefs.getInt(_kCalendarDays) ?? 21).clamp(1, 90)).toInt();
    token = _prefs.getString(_kToken);
    apiKey = _prefs.getString(_kApiKey);
    if (hasServer && token != null && token!.isNotEmpty) {
      try {
        await _loadSession();
      } on ApiException catch (e) {
        if (e.isUnauthorized) {
          await _clearCredentials(notify: false);
        } else {
          sessionError = e.message;
        }
      } catch (e) {
        sessionError = '$e';
      }
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> _loadSession() async {
    sessionError = null;
    me = asMap(await client.get('/auth/me'));
    try {
      settings = asMap(await client.get('/auth/settings'));
    } catch (_) {
      settings = null;
    }
  }

  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    bool remember = false,
  }) async {
    final result = asMap(await ApiClient(baseUrl: proxyUrl).postForm(
      '/auth/login',
      {
        'username': username.trim(),
        'password': password,
        'remember': remember,
      },
    ));
    if (result['requires_2fa'] == true) return result;
    await _applyToken(result.s('access_token')!);
    return result;
  }

  Future<Map<String, dynamic>> completeTwoFactor(
    String tempToken,
    String code,
  ) async {
    final result = asMap(await ApiClient(baseUrl: proxyUrl).post(
      '/auth/2fa/verify-login',
      {'temp_token': tempToken, 'code': code.trim()},
    ));
    await _applyToken(result.s('access_token')!);
    return result;
  }

  Future<void> _applyToken(String value) async {
    token = value;
    apiKey = null;
    _client = null;
    await _prefs.setString(_kToken, value);
    await _prefs.remove(_kApiKey);
    await _loadSession();
    notifyListeners();
  }

  Future<void> loginWithApiKey(String key) async {
    final value = key.trim();
    final check = ApiClient(baseUrl: proxyUrl, apiKey: value);
    await check.get('/history', {'page': 1, 'page_size': 1});
    await _clearCredentials(notify: false);
    apiKey = value;
    await _prefs.setString(_kApiKey, value);
    _client = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (token == null) return;
    try {
      await _loadSession();
    } on ApiException catch (e) {
      sessionError = e.message;
      if (e.isUnauthorized) await _clearCredentials(notify: false);
    } catch (e) {
      sessionError = '$e';
    }
    notifyListeners();
  }

  Future<void> logout() => _clearCredentials();

  Future<void> _clearCredentials({bool notify = true}) async {
    token = null;
    apiKey = null;
    me = null;
    settings = null;
    sessionError = null;
    _client = null;
    _followingListId = null;
    _followingItems = null;
    await _prefs.remove(_kToken);
    await _prefs.remove(_kApiKey);
    await _prefs.remove(_kFollowingListId);
    await _prefs.remove(_kFollowingMirror);
    if (notify) notifyListeners();
  }

  Future<void> setServer(String value) async {
    final next = normalizeOrigin(value);
    if (next.isEmpty || next == server) return;
    await _clearCredentials(notify: false);
    server = next;
    await _prefs.setString(_kServer, next);
    notifyListeners();
  }

  Future<void> setShowLibraryTab(bool value) async {
    showLibraryTab = value;
    await _prefs.setBool(_kShowLibrary, value);
    notifyListeners();
  }

  Future<void> setCalendarDays(int value) async {
    calendarDays = value.clamp(1, 90).toInt();
    await _prefs.setInt(_kCalendarDays, calendarDays);
    notifyListeners();
  }

  int? _followingListId;
  List<Map<String, dynamic>>? _followingItems;

  bool _isFollowingList(Map<String, dynamic> list) =>
      (list.s('description') ?? '').contains(_kFollowingMarker);

  Future<int> ensureFollowingList() async {
    if (_followingListId != null) return _followingListId!;

    final stored = _prefs.getInt(_kFollowingListId);
    if (stored != null && await _useFollowingList(stored)) {
      return stored;
    }

    final lists = asMap(await get('/lists')).maps('lists');
    for (final list in lists) {
      if (!_isFollowingList(list)) continue;
      final id = list.i('id');
      if (id != null && await _useFollowingList(id)) return id;
    }

    final created = asMap(await post('/lists', {
      'name': kFollowingListName,
      'description': _kFollowingMarker,
      'privacy_level': 'private',
    }));
    final id = created.i('id');
    if (id == null) {
      throw ApiException(0, 'Could not create the Following list');
    }
    _followingListId = id;
    await _prefs.setInt(_kFollowingListId, id);
    await _restoreFollowingMirror(id);
    return id;
  }

  Future<void> _restoreFollowingMirror(int id) async {
    final raw = _prefs.getString(_kFollowingMirror);
    if (raw == null || raw.isEmpty) return;
    try {
      for (final media in asMaps(jsonDecode(raw))) {
        final tmdbId = media.i('tmdb_id');
        final type = media.s('type');
        if (tmdbId == null || type == null) continue;
        try {
          await post('/lists/$id/items', {
            'tmdb_id': tmdbId,
            'media_type': type,
          });
        } catch (_) {
          // One stale item must not block the rest of the restore.
        }
      }
    } catch (_) {
      // Ignore a corrupt mirror; the list itself is still usable.
    }
  }

  Future<bool> _useFollowingList(int id) async {
    try {
      final list = asMap(await get('/lists/$id'));
      if (list.i('id') == null) return false;
      if (list.s('privacy_level') != 'private') {
        await patch('/lists/$id', {
          'name': list.s('name'),
          'description': list.s('description'),
          'privacy_level': 'private',
        });
      }
      _followingListId = id;
      await _prefs.setInt(_kFollowingListId, id);
      return true;
    } on ApiException catch (e) {
      if (e.status == 404) return false;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> followingItems({
    bool refresh = false,
  }) async {
    if (!refresh && _followingItems != null) return _followingItems!;
    final id = await ensureFollowingList();
    try {
      final list = asMap(await get('/lists/$id'));
      final items = list.maps('items');
      _followingItems = items;
      final media = items.map((item) => asMap(item['media'])).toList();
      await _prefs.setString(_kFollowingMirror, jsonEncode(media));
      return items;
    } catch (_) {
      final raw = _prefs.getString(_kFollowingMirror);
      if (raw != null && raw.isNotEmpty) {
        try {
          return asMaps(jsonDecode(raw));
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<bool> isFollowing(String type, int tmdbId) async {
    final items = await followingItems();
    return items.any((item) {
      final media = asMap(item['media']);
      return media.s('type') == type && media.i('tmdb_id') == tmdbId;
    });
  }

  Future<bool> toggleFollowing(String type, int tmdbId) async {
    final listId = await ensureFollowingList();
    final items = await followingItems(refresh: true);
    Map<String, dynamic>? existing;
    for (final item in items) {
      final media = asMap(item['media']);
      if (media.s('type') == type && media.i('tmdb_id') == tmdbId) {
        existing = item;
        break;
      }
    }

    if (existing != null) {
      final itemId = existing.i('id');
      if (itemId != null) {
        await delete('/lists/$listId/items/$itemId');
      }
    } else {
      await post('/lists/$listId/items', {
        'tmdb_id': tmdbId,
        'media_type': type,
      });
    }

    _followingItems = null;
    bumpFollowing();
    final updated = await followingItems(refresh: true);
    return updated.any((item) {
      final media = asMap(item['media']);
      return media.s('type') == type && media.i('tmdb_id') == tmdbId;
    });
  }

  /// Checks that the URL points at a live Scrob API before it is saved.
  static Future<String> verifyServer(String value) async {
    final origin = normalizeOrigin(value);
    if (origin.isEmpty) {
      throw ApiException(0, 'Enter your server URL');
    }
    final api = ApiClient(baseUrl: '$origin/api/proxy');
    try {
      final data = asMap(await api.get('/auth/has-users'));
      if (!data.containsKey('has_users')) {
        throw ApiException(0, 'That URL is not a Scrob server.');
      }
      return origin;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 404) {
        throw ApiException(e.status, 'No Scrob server found at $origin');
      }
      throw ApiException(
        e.status,
        'Could not connect to $origin: ${e.message}',
      );
    } catch (_) {
      throw ApiException(0, 'Could not connect to $origin');
    }
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) =>
      _guard(() => client.get(path, query));

  Future<dynamic> post(
    String path, [
    Object? body,
    Map<String, dynamic>? query,
  ]) =>
      _guard(() => client.post(path, body, query));

  Future<dynamic> patch(
    String path, [
    Object? body,
    Map<String, dynamic>? query,
  ]) =>
      _guard(() => client.patch(path, body, query));

  Future<dynamic> put(
    String path, [
    Object? body,
    Map<String, dynamic>? query,
  ]) =>
      _guard(() => client.put(path, body, query));

  Future<dynamic> delete(String path, [Map<String, dynamic>? query]) =>
      _guard(() => client.delete(path, query));

  Future<Uint8List> getBytes(
    String path, [
    Map<String, dynamic>? query,
  ]) async =>
      await _guard(() => client.getBytes(path, query)) as Uint8List;

  Future<dynamic> postMultipart(
    String path, {
    required String field,
    required Uint8List bytes,
    required String filename,
    Map<String, String> fields = const {},
    String? mimeType,
  }) =>
      _guard(() => client.postMultipart(
            path,
            field: field,
            bytes: bytes,
            filename: filename,
            fields: fields,
            mimeType: mimeType,
          ));

  Future<dynamic> _guard(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      if (e.isUnauthorized && token != null) {
        await _clearCredentials();
      }
      rethrow;
    }
  }

  Future<dynamic> tryGet(String path, [Map<String, dynamic>? query]) async {
    try {
      return await get(path, query);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateSettings(Map<String, dynamic> patch) async {
    final result = await this.patch('/auth/settings', patch);
    settings = asMap(result);
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> patch) async {
    await this.patch('/profile/me', patch);
    await refresh();
  }

  int avatarVersion = 0;
  int historyRevision = 0;
  int followingRevision = 0;

  void bumpHistory() {
    historyRevision++;
    notifyListeners();
  }

  void bumpFollowing() {
    followingRevision++;
    notifyListeners();
  }

  void bumpAvatar() {
    avatarVersion++;
    notifyListeners();
  }

  String? imageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('/')) {
      var url = '$proxyUrl$path';
      if (path.contains('/profile/avatar/')) {
        url = '$url${url.contains('?') ? '&' : '?'}v=$avatarVersion';
      }
      return url;
    }
    // The image proxy accepts a JWT, not an API key. In API-key mode use the
    // public TMDB/TVDB URL directly so covers still render.
    if (apiKey != null && apiKey!.isNotEmpty && token == null) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return path;
      }
    }
    final tmdb =
        RegExp(r'image\.tmdb\.org/t/p/[^/]+(/.*)$').firstMatch(path);
    if (tmdb != null) return '$proxyUrl/media/image/$size${tmdb.group(1)}';
    final tvdb = RegExp(r'artworks\.thetvdb\.com(/.*)$').firstMatch(path);
    if (tvdb != null) return '$proxyUrl/media/image/tvdb${tvdb.group(1)}';
    return path;
  }

  /// Public fallback for a proxied poster URL, used only when the
  /// authenticated image proxy fails. TMDB artwork is public.
  String? directImageUrl(String? url) {
    if (url == null) return null;
    final tmdb = RegExp(
      r'/api/proxy/media/image/(w\d+|original)/(.+)$',
    ).firstMatch(url);
    if (tmdb != null) {
      return 'https://image.tmdb.org/t/p/${tmdb.group(1)}/${tmdb.group(2)}';
    }
    final tvdb = RegExp(
      r'/api/proxy/media/image/tvdb(/.*)$',
    ).firstMatch(url);
    if (tvdb != null) {
      return 'https://artworks.thetvdb.com${tvdb.group(1)}';
    }
    return null;
  }

  /// Headers for own-proxy images. The media-image endpoint requires a JWT
  /// even though posters contain no private data. Dart's HttpClient strips
  /// Authorization/Cookie on cross-origin redirects, so the header cannot leak
  /// when the proxy 302s to image.tmdb.org.
  Map<String, String>? imageHeaders(String? url) {
    if (!hasServer || url == null || !url.startsWith(proxyUrl)) return null;
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      'X-Api-Key': (apiKey != null && apiKey!.isNotEmpty)
          ? apiKey!
          : ApiClient.proxyGateKey,
    };
  }
}

class ScrobScope extends InheritedNotifier<AppState> {
  const ScrobScope({
    required AppState super.notifier,
    required super.child,
    super.key,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ScrobScope>();
    assert(scope != null, 'ScrobScope is missing above this widget');
    return scope!.notifier!;
  }
}
