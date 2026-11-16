import 'api.dart';
import 'format.dart';

/// Returns a fresh JWT from `/auth/session/renew`, or null when the server
/// declines to slide the session (typed token, too-new token, or an error).
Future<String?> renewSessionToken(ApiClient client) async {
  try {
    final data = asMap(await client.post('/auth/session/renew'));
    final token = data.s('access_token');
    return token == null || token.isEmpty ? null : token;
  } catch (_) {
    return null;
  }
}
