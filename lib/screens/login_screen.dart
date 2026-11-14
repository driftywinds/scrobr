import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _apiKey = TextEditingController();
  bool _remember = true;
  bool _obscure = true;
  bool _busy = false;
  bool _apiKeyMode = false;
  String? _error;
  bool _registrationEnabled = false;

  bool _registrationChecked = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_registrationChecked) {
      _registrationChecked = true;
      _checkRegistration();
    }
  }

  Future<void> _checkRegistration() async {
    final app = ScrobScope.of(context);
    final result = await app.tryGet('/auth/registration-status');
    if (!mounted) return;
    setState(() => _registrationEnabled = asMap(result).b('enabled'));
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = ScrobScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_apiKeyMode) {
        await app.loginWithApiKey(_apiKey.text);
      } else {
        final result = await app.login(
          _username.text,
          _password.text,
          remember: _remember,
        );
        if (result['requires_2fa'] == true) {
          final code = await _askTwoFactor();
          if (code == null || code.trim().isEmpty) {
            throw ApiException(0, 'Two-factor code is required');
          }
          await app.completeTwoFactor(result.s('temp_token')!, code);
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askTwoFactor() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Two-factor authentication'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '6-digit code or backup code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Verify'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _changeServer() async {
    final app = ScrobScope.of(context);
    final controller = TextEditingController(text: app.server);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scrob server'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'https://scrob.example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.trim().isNotEmpty) {
      await app.setServer(value);
      if (mounted) {
        setState(() => _error = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server set to ${app.server}')),
        );
      }
    }
  }

  Future<void> _register() async {
    final app = ScrobScope.of(context);
    final email = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created != true) {
      email.dispose();
      username.dispose();
      password.dispose();
      return;
    }
    try {
      await ApiClient(baseUrl: app.proxyUrl).post('/auth/register', {
        'email': email.text.trim(),
        'username': username.text.trim(),
        'password': password.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Check your email if validation is on.'),
        ),
      );
      _username.text = username.text.trim();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      email.dispose();
      username.dispose();
      password.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/scrob.png',
                      width: 88,
                      height: 88,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.movie_filter_rounded,
                        size: 80,
                        color: kAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Scrob',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your library, watch history and lists.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF27272A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Password')),
                            ButtonSegment(value: true, label: Text('API key')),
                          ],
                          selected: {_apiKeyMode},
                          onSelectionChanged: (value) => setState(() {
                            _apiKeyMode = value.first;
                            _error = null;
                          }),
                        ),
                        const SizedBox(height: 18),
                        if (_apiKeyMode) ...[
                          TextField(
                            controller: _apiKey,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Scrob API key',
                              hintText: 'Paste your API key',
                              prefixIcon: Icon(Icons.key_rounded),
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'API-key sessions can browse, track and sync data. '
                            'Account, comments and admin settings need a password login.',
                            style: TextStyle(color: kMuted, fontSize: 11),
                          ),
                        ] else ...[
                          TextField(
                            controller: _username,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _password,
                            obscureText: _obscure,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _remember,
                            onChanged: (v) =>
                                setState(() => _remember = v ?? true),
                            title: const Text(
                              'Stay logged in',
                              style: TextStyle(fontSize: 12),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(color: kDanger, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_apiKeyMode ? 'Connect' : 'Sign in'),
                        ),
                        if (_registrationEnabled && !_apiKeyMode) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _busy ? null : _register,
                            child: const Text('Create an account'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: _changeServer,
                    icon: const Icon(Icons.dns_outlined, size: 16),
                    label: Text(
                      app.server.replaceFirst(RegExp(r'^https?://'), ''),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
