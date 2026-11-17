import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _apiKey = TextEditingController();
  final _serverUrl = TextEditingController();
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
    final app = ScrobScope.of(context);
    if (app.hasServer && !_registrationChecked) {
      _registrationChecked = true;
      _checkRegistration();
    }
  }

  Future<void> _checkRegistration() async {
    final app = ScrobScope.of(context);
    if (!app.hasServer) return;
    final result = await app.tryGet('/auth/registration-status');
    if (!mounted) return;
    setState(() => _registrationEnabled = asMap(result).b('enabled'));
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _apiKey.dispose();
    _serverUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = ScrobScope.of(context);
    if (!app.hasServer) {
      setState(() => _error = 'Connect to your server first');
      return;
    }
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
        TextInput.finishAutofillContext();
        if (result['requires_2fa'] == true) {
          final temp = result.s('temp_token');
          if (temp == null || temp.isEmpty) {
            throw ApiException(0, 'Server did not return a 2FA challenge token');
          }
          final ok = await _promptTwoFactor(temp);
          if (!ok) return;
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

  Future<bool> _promptTwoFactor(String tempToken) async {
    if (!mounted) return false;
    final app = ScrobScope.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TwoFactorDialog(app: app, tempToken: tempToken),
    );
    return result == true;
  }

  Future<void> _connectServer() async {
    final app = ScrobScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final origin = await AppState.verifyServer(_serverUrl.text);
      await app.setServer(origin);
      _registrationChecked = false;
      await _checkRegistration();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            hintText: 'https://your-server.example',
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
    if (value == null || value.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final origin = await AppState.verifyServer(value);
      await app.setServer(origin);
      _registrationChecked = false;
      await _checkRegistration();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server set to ${app.server}')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final app = ScrobScope.of(context);
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Account email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        final result = asMap(await ApiClient(baseUrl: app.proxyUrl).post(
          '/auth/forgot-password',
          {'email': email.text.trim()},
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.s('message') ?? 'Check your email'),
            ),
          );
        }
      } on ApiException catch (e) {
        if (mounted) setState(() => _error = e.message);
      }
    }
    email.dispose();
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

  Widget _serverSetup() {
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
                  const _BrandHeader(
                    subtitle: 'Connect to your own Scrob server to get started.',
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: kBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Server URL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'The app verifies the server before saving it. '
                          'Use the address of your self-hosted Scrob instance.',
                          style: TextStyle(
                            fontSize: 11,
                            color: kMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _serverUrl,
                          autofocus: true,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          onSubmitted: (_) {
                            if (!_busy) _connectServer();
                          },
                          decoration: const InputDecoration(
                            labelText: 'Server URL',
                            hintText: 'https://your-server.example',
                            prefixIcon: Icon(Icons.dns_outlined),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          _ErrorBanner(_error!),
                        ],
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _busy ? null : _connectServer,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
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
                              : const Text('Connect'),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    if (!app.hasServer) return _serverSetup();
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
                  const _BrandHeader(
                    subtitle: 'Your library, watch history and lists.',
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: kBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        SegmentedTabs<bool>(segments: const [
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
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
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
                          _ErrorBanner(_error!),
                        ],
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
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
                        if (!_apiKeyMode)
                          TextButton(
                            onPressed: _busy ? null : _forgotPassword,
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
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

class _TwoFactorDialog extends StatefulWidget {
  const _TwoFactorDialog({required this.app, required this.tempToken});

  final AppState app;
  final String tempToken;

  @override
  State<_TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<_TwoFactorDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter your authenticator code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.app.completeTwoFactor(widget.tempToken, code);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        _code.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _code.text.length,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Two-factor authentication'),
      content: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-digit code from your authenticator app. A backup code also works.',
              style: TextStyle(fontSize: 12, color: kMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              onSubmitted: (_) => _verify(),
              decoration: const InputDecoration(
                labelText: 'Authenticator code',
                hintText: '123456',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: kDanger, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}

/// Logo with a soft accent glow, app name and a one-line subtitle.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kAccent.withValues(alpha: 0.28),
                    kAccent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            SvgPicture.asset(
              'assets/scrobr.svg',
              width: 84,
              height: 84,
              placeholderBuilder: (_) => Icon(
                Icons.movie_filter_rounded,
                size: 76,
                color: kAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Scrobr',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kMuted, fontSize: 13.5),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kDanger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDanger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: kDanger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
