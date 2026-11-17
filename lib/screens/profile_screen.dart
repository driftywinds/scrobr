import 'package:file_picker/file_picker.dart';
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

  Future<Map<String, dynamic>> _load(int id) async {
    final app = ScrobScope.of(context);
    final results = await Future.wait([
      app.get('/profile/$id'),
      app.tryGet('/profile/$id/stats'),
    ]);
    final profile = asMap(results[0]);
    profile['_stats'] = asMap(results[1]);
    return profile;
  }

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
        title: const Text('Profile'),
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
              if (value == 'avatar' && isOwn) _changeAvatar();
              if (value == 'removeAvatar' && isOwn) _removeAvatar();
            },
            itemBuilder: (_) => [
              if (isOwn) ...[
                const PopupMenuItem(value: 'edit', child: Text('Edit profile')),
                const PopupMenuItem(
                  value: 'avatar',
                  child: Text('Change avatar'),
                ),
                const PopupMenuItem(
                  value: 'removeAvatar',
                  child: Text('Remove avatar'),
                ),
              ],
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
    if (ok == true) await signOut(context);
  }

  String? _avatarMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
  }

  Future<void> _changeAvatar() async {
    final picked = await FilePicker.pickFile(type: FileType.image);
    if (picked == null) return;
    final mime = _avatarMime(picked.name);
    if (mime == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use a JPEG, PNG or WebP image')),
        );
      }
      return;
    }
    final app = ScrobScope.of(context);
    try {
      final bytes = await picked.readAsBytes();
      await app.postMultipart(
        '/profile/me/avatar',
        field: 'file',
        bytes: bytes,
        filename: picked.name.isEmpty ? 'avatar.jpg' : picked.name,
        mimeType: mime,
      );
      await app.refresh();
      app.bumpAvatar();
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update avatar: $e')),
        );
      }
    }
  }

  Future<void> _removeAvatar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove avatar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final app = ScrobScope.of(context);
    try {
      await app.delete('/profile/me/avatar');
      await app.refresh();
      app.bumpAvatar();
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove avatar: $e')),
        );
      }
    }
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
    final stats = asMap(profile['_stats']);
    final avatar = app.imageUrl(_avatar);
    final banner = app.imageUrl(
      profile.s('banner_url') ??
          profile.s('banner_path') ??
          profile.s('banner'),
      size: 'w1280',
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        if (banner != null)
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CachedArtwork(
                        url: banner,
                        fit: BoxFit.cover,
                        placeholder: Container(color: kSurface),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 32,
                  top: 58,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: kBg,
                    ),
                    child: UserAvatar(
                      url: avatar,
                      name: profile.s('display_name'),
                      size: 84,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                UserAvatar(
                  url: avatar,
                  name: profile.s('display_name'),
                  size: 72,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.s('display_name') ??
                            profile.s('username') ??
                            '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${profile.s('username') ?? ''} · Joined ${fmtDate(profile.s('created_at'))}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (banner != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.s('display_name') ?? profile.s('username') ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${profile.s('username') ?? ''} · Joined ${fmtDate(profile.s('created_at'))}',
                  style: const TextStyle(fontSize: 12, color: kMuted),
                ),
              ],
            ),
          ),
        if (profile.s('bio') != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              profile.s('bio')!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: kBody,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: isOwn
                    ? ActionPill(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: onEdit,
                      )
                    : ActionPill(
                        icon: profile.b('is_following')
                            ? Icons.person_remove_alt_1_outlined
                            : Icons.person_add_alt_1_outlined,
                        label: profile.b('is_following') ? 'Unfollow' : 'Follow',
                        active: profile.b('is_following'),
                        onTap: () => _follow(context),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ActionPill(
                  icon: Icons.insights_rounded,
                  label: 'Stats',
                  onTap: () {
                    final id = profile.i('id');
                    if (id != null) openStats(context, id);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ActionPill(
                  icon: Icons.view_list_rounded,
                  label: 'Lists',
                  onTap: () => openLists(context),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: panelDecoration(),
          child: Row(
            children: [
              _Stat(
                label: 'Watch time',
                value: stats.isEmpty
                    ? '—'
                    : fmtMinutes(stats.i('total_watch_minutes')),
              ),
              const _StatDivider(),
              _Stat(
                label: 'Movies',
                value: fmtCount(profile.i('movies_watched')),
              ),
              const _StatDivider(),
              _Stat(
                label: 'Shows',
                value: fmtCount(profile.i('shows_watched')),
              ),
              const _StatDivider(),
              _Stat(
                label: 'Rated',
                value: fmtCount(profile.i('total_rated')),
              ),
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
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Lists'),
                const SizedBox(height: 10),
                ...lists.map(
                  (list) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(kRadius),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(kRadius),
                        onTap: () {
                          final id = list.i('id');
                          if (id != null) openList(context, id);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(kRadius),
                            border: Border.all(color: kBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: kAccent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  list.b('is_watchlist')
                                      ? Icons.bookmark_rounded
                                      : Icons.list_alt_rounded,
                                  size: 20,
                                  color: kAccentSoft,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      list.s('name') ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${list.i('item_count') ?? 0} items · ${list.s('privacy_level') ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: kMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: kMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: kMuted),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: kBorder);
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
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
                    size: 48,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    truncate(
                      person.s('display_name') ?? person.s('username') ?? '',
                      12,
                    ),
                    style: const TextStyle(fontSize: 10, color: kMuted),
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
                Row(
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
                  onPressed: () => signOut(context),
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
