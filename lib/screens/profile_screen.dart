import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'profile_media_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId});

  final int? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>>? _future;
  int? _loadedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = ScrobScope.of(context);
    final id = widget.userId ?? app.userId;
    if (id != _loadedId) {
      _loadedId = id;
      _future = id == null ? null : _load(id);
    }
  }

  Future<Map<String, dynamic>> _load(int id) async =>
      asMap(await ScrobScope.of(context).get('/profile/$id'));

  void _reload() {
    final id = _loadedId;
    if (id != null) setState(() => _future = _load(id));
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final isOwn = widget.userId == null || widget.userId == app.userId;

    if (app.isApiKeyMode) {
      return _ApiKeyProfile(onSettings: () => openSettings(context));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwn ? 'Profile' : 'Profile'),
        actions: [
          IconButton(
            tooltip: 'Search users',
            onPressed: () => openSearch(context),
            icon: const Icon(Icons.person_search_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _logout();
              if (value == 'edit' && isOwn) _edit();
            },
            itemBuilder: (_) => [
              if (isOwn)
                const PopupMenuItem(value: 'edit', child: Text('Edit profile')),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const EmptyState(title: 'No profile available');
          }
          return _ProfileBody(
            profile: profile,
            isOwn: isOwn,
            onReload: _reload,
            onEdit: _edit,
            onLogout: _logout,
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    final app = ScrobScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) await app.logout();
  }

  Future<void> _edit() async {
    final app = ScrobScope.of(context);
    final profile = asMap(await app.get('/profile/me'));
    final name = TextEditingController(text: profile.s('display_name'));
    final bio = TextEditingController(text: profile.s('bio'));
    final country = TextEditingController(text: profile.s('country'));
    final metadataLanguage =
        TextEditingController(text: profile.s('metadata_language'));
    final contentLanguage =
        TextEditingController(text: profile.s('content_language'));
    var privacy = profile.s('privacy_level') ?? 'private';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bio,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: country,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: metadataLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Metadata language',
                    hintText: 'e.g. en-US',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Content language',
                    hintText: 'e.g. en',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: privacy,
                  items: const [
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                    DropdownMenuItem(
                      value: 'friends_only',
                      child: Text('Friends only'),
                    ),
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                  ],
                  onChanged: (v) => setState(() => privacy = v ?? 'private'),
                  decoration: const InputDecoration(labelText: 'Privacy'),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await app.updateProfile({
        'display_name': name.text.trim(),
        'bio': bio.text.trim().isEmpty ? null : bio.text.trim(),
        'country': country.text.trim().isEmpty ? null : country.text.trim(),
        'metadata_language': metadataLanguage.text.trim().isEmpty
            ? null
            : metadataLanguage.text.trim(),
        'content_language': contentLanguage.text.trim().isEmpty
            ? null
            : contentLanguage.text.trim(),
        'privacy_level': privacy,
      });
      _reload();
    }
    name.dispose();
    bio.dispose();
    country.dispose();
    metadataLanguage.dispose();
    contentLanguage.dispose();
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.isOwn,
    required this.onReload,
    required this.onEdit,
    required this.onLogout,
  });

  final Map<String, dynamic> profile;
  final bool isOwn;
  final VoidCallback onReload;
  final VoidCallback onEdit;
  final VoidCallback onLogout;

  String? get _avatar {
    final value = profile.s('avatar_url');
    return value;
  }

  Map<String, dynamic> _asMedia(Map<String, dynamic> item) {
    final type = item.s('media_type') ?? item.s('type') ?? 'movie';
    return {
      ...item,
      'type': type == 'show' ? 'series' : type,
      'title': item.s('title') ?? '',
    };
  }

  void _openMore(BuildContext context, String kind, String title) {
    final id = profile.i('id');
    if (id == null) return;
    pushScreen(
      context,
      ProfileMediaScreen(userId: id, kind: kind, title: title),
    );
  }

  Future<void> _follow(BuildContext context) async {
    final app = ScrobScope.of(context);
    final id = profile.i('id');
    if (id == null) return;
    try {
      if (profile.b('is_following')) {
        await app.delete('/profile/$id/follow');
      } else {
        await app.post('/profile/$id/follow');
      }
      onReload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update follow: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final topMovies = profile.maps('top_rated_movies');
    final topShows = profile.maps('top_rated_shows');
    final recentMovies = profile.maps('recently_watched_movies');
    final recentShows = profile.maps('recently_watched_shows');
    final lists = profile.maps('lists');
    final followers = profile.maps('followers');
    final following = profile.maps('following');
    final avatar = app.imageUrl(_avatar);

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                url: avatar,
                name: profile.s('display_name'),
                size: 76,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.s('display_name') ?? profile.s('username') ?? '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '@${profile.s('username') ?? ''}',
                      style: const TextStyle(fontSize: 12, color: kMuted),
                    ),
                    if (profile.s('bio') != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        profile.s('bio')!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFFD4D4D8),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Joined ${fmtDate(profile.s('created_at'))}',
                      style: const TextStyle(fontSize: 10, color: kMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isOwn)
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit profile'),
                ),
              if (!isOwn)
                FilledButton.tonalIcon(
                  onPressed: () => _follow(context),
                  icon: Icon(
                    profile.b('is_following')
                        ? Icons.person_remove_outlined
                        : Icons.person_add_alt_1_outlined,
                    size: 16,
                  ),
                  label: Text(
                    profile.b('is_following') ? 'Unfollow' : 'Follow',
                  ),
                ),
              FilledButton.tonalIcon(
                onPressed: () {
                  final id = profile.i('id');
                  if (id != null) openStats(context, id);
                },
                icon: const Icon(Icons.insights_rounded, size: 16),
                label: const Text('Stats'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => openLists(context),
                icon: const Icon(Icons.list_alt_rounded, size: 16),
                label: const Text('Lists'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _Stat(label: 'Watched', value: profile.i('total_watched') ?? 0),
              _Stat(label: 'Movies', value: profile.i('movies_watched') ?? 0),
              _Stat(label: 'Shows', value: profile.i('shows_watched') ?? 0),
              _Stat(label: 'Rated', value: profile.i('total_rated') ?? 0),
            ],
          ),
        ),
        if (following.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _PeopleStrip(
              title: 'Following',
              people: following,
              onTap: (id) => openProfile(context, id),
            ),
          ),
        if (followers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _PeopleStrip(
              title: 'Followers',
              people: followers,
              onTap: (id) => openProfile(context, id),
            ),
          ),
        if (topMovies.isNotEmpty)
          MediaRow(
            title: 'Top Rated Movies',
            items: topMovies.map(_asMedia).toList(),
            onSeeAll: () => _openMore(
              context,
              'top-rated-movies',
              'Top Rated Movies',
            ),
          ),
        if (topShows.isNotEmpty)
          MediaRow(
            title: 'Top Rated Shows',
            items: topShows.map(_asMedia).toList(),
            onSeeAll: () => _openMore(
              context,
              'top-rated-shows',
              'Top Rated Shows',
            ),
          ),
        if (recentMovies.isNotEmpty)
          MediaRow(
            title: 'Recently Watched Movies',
            items: recentMovies.map(_asMedia).toList(),
            onSeeAll: () => _openMore(
              context,
              'recently-watched-movies',
              'Recently Watched Movies',
            ),
          ),
        if (recentShows.isNotEmpty)
          MediaRow(
            title: 'Recently Watched Shows',
            items: recentShows.map(_asMedia).toList(),
            onSeeAll: () => _openMore(
              context,
              'recently-watched-shows',
              'Recently Watched Shows',
            ),
          ),
        if (lists.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lists',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                ...lists.map(
                  (list) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      list.b('is_watchlist')
                          ? Icons.bookmark_rounded
                          : Icons.list_alt_rounded,
                    ),
                    title: Text(list.s('name') ?? ''),
                    subtitle: Text(
                      '${list.i('item_count') ?? 0} items · ${list.s('privacy_level') ?? ''}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    onTap: () {
                      final id = list.i('id');
                      if (id != null) openList(context, id);
                    },
                  ),
                ),
              ],
            ),
          ),
        if (isOwn)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Sign out'),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            fmtCount(value),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: kMuted),
          ),
        ],
      ),
    );
  }
}

class _PeopleStrip extends StatelessWidget {
  const _PeopleStrip({
    required this.title,
    required this.people,
    required this.onTap,
  });

  final String title;
  final List<Map<String, dynamic>> people;
  final void Function(int userId) onTap;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: people.map((person) {
            return InkWell(
              onTap: () {
                final id = person.i('id');
                if (id != null) onTap(id);
              },
              child: Column(
                children: [
                  UserAvatar(
                    url: app.imageUrl(person.s('avatar_url')),
                    name: person.s('display_name') ?? person.s('username'),
                    size: 44,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    truncate(
                      person.s('display_name') ?? person.s('username') ?? '',
                      12,
                    ),
                    style: const TextStyle(fontSize: 9, color: kMuted),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ApiKeyProfile extends StatelessWidget {
  const _ApiKeyProfile({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.key_rounded, color: kAccent),
                    SizedBox(width: 8),
                    Text(
                      'API-key session',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can browse, track and sync. Sign in with your password for comments, account settings, connections and admin tools.',
                  style: TextStyle(fontSize: 12, color: kMuted, height: 1.4),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => app.logout(),
                  child: const Text('Switch account'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.list_alt_rounded),
            title: const Text('My lists'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openLists(context),
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Watch history'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openHistory(context),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Calendar'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openCalendar(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}
