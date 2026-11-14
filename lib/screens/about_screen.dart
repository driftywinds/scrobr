import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Image.asset(
              'assets/scrob.png',
              width: 84,
              height: 84,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.movie_filter_rounded,
                size: 72,
                color: kAccent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Scrobr',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Your library, watch history and lists.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kMuted),
          ),
          const SizedBox(height: 20),
          _AboutTile(
            icon: Icons.dns_outlined,
            title: 'Server',
            subtitle: app.server,
          ),
          _AboutTile(
            icon: Icons.info_outline_rounded,
            title: 'Android app',
            subtitle: 'Version $_version',
          ),
          _AboutTile(
            icon: Icons.code_rounded,
            title: 'Scrob server source',
            subtitle: 'github.com/ellite/scrob',
            onTap: () => launchUrl(
              Uri.parse('https://github.com/ellite/scrob'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          _AboutTile(
            icon: Icons.public_rounded,
            title: 'Open web UI',
            subtitle: app.server,
            onTap: () => launchUrl(
              Uri.parse(app.server),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Scrob is self-hosted media tracking software. This client talks to '
            'your server’s API and stores your session token locally on the device.',
            style: TextStyle(fontSize: 11, height: 1.5, color: kMuted),
          ),
        ],
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: kAccent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
      trailing:
          onTap == null ? null : const Icon(Icons.open_in_new_rounded, size: 16),
      onTap: onTap,
    );
  }
}
