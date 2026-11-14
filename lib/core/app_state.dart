import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'format.dart';

const _kServer = 'scrob_server';
const _kToken = 'scrob_token';
const _kApiKey = 'scrob_api_key';

class AppState extends ChangeNotifier {
  AppState({String? initialServer})
      : server = normalizeOrigin(initialServer ?? defaultServer);

  static const String defaultServer = String.fromEnvironment(
    'SCROB_SERVER',
    defaultValue: 'https://scrob.003274.xyz',
  );

  late SharedPreferences _prefs;
  ApiClient? _client;

  String server;
  String? token;
  String? apiKey;
  Map<String, dynamic>? me;
  Map<String, dynamic>? settings;
  bool initialized = false;
  String? sessionError;

  bool get isLoggedIn => token != null || apiKey != null;
  bool get isApiKeyMode => token == null && apiKey != null;
  bool get isAdmin => me?.b('is_admin') ?? false;
  int? get userId => me?.i('id');
  String get displayName =>
      me?.s('display_name') ?? me?.s('username') ?? (isApiKeyMode ? 'API key' : 'Scrob user');
  String get origin => server;
  String get proxyUrl => '$server/api/proxy';

  ApiClient get client => _client ??= ApiClient(
        baseUrl: proxyUrl,
        token: token,
        apiKey: apiKey,
      );

  static String normalizeOrigin(String value) {
    var s = value.trim();
    if (s.isEmpty) s = defaultServer;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
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
    server = normalizeOrigin(_prefs.getString(_kServer) ?? defaultServer);
    token = _prefs.getString(_kToken);
    apiKey = _prefs.getString(_kApiKey);
    if (token != null && token!.isNotEmpty) {
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
    await _prefs.remove(_kToken);
    await _prefs.remove(_kApiKey);
    if (notify) notifyListeners();
  }

  Future<void> setServer(String value) async {
    final next = normalizeOrigin(value);
    if (next == server) return;
    await _clearCredentials(notify: false);
    server = next;
    await _prefs.setString(_kServer, next);
    notifyListeners();
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

  String? imageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('/')) return '$proxyUrl$path';
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

  /// Headers for own-proxy images. The media-image endpoint requires a JWT
  /// even though posters contain no private data. Dart's HttpClient strips
  /// Authorization/Cookie on cross-origin redirects, so the header cannot leak
  /// when the proxy 302s to image.tmdb.org.
  Map<String, String>? imageHeaders(String? url) {
    if (url == null || !url.startsWith(proxyUrl)) return null;
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
