import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'list_detail_screen.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  String _tab = 'mine';
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final app = ScrobScope.of(context);
    final data = asMap(
      await app.get(_tab == 'mine' ? '/lists' : '/lists/public'),
    );
    return data.maps('lists');
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _create() async {
    final name = TextEditingController();
    final description = TextEditingController();
    var privacy = 'private';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New list'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      name.dispose();
      description.dispose();
      return;
    }
    try {
      final list = asMap(await ScrobScope.of(context).post('/lists', {
        'name': name.text.trim(),
        'description': description.text.trim().isEmpty
            ? null
            : description.text.trim(),
        'privacy_level': privacy,
      }));
      _reload();
      if (mounted && list.i('id') != null) {
        pushScreen(context, ListDetailScreen(listId: list.i('id')!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create list: $e')),
        );
      }
    } finally {
      name.dispose();
      description.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lists'),
        actions: [
          if (_tab == 'mine')
            IconButton(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SegmentedTabs<String>(segments: const [
                ButtonSegment(value: 'mine', label: Text('My lists')),
                ButtonSegment(value: 'public', label: Text('Public')),
              ],
              selected: {_tab},
              onSelectionChanged: (value) {
                setState(() => _tab = value.first);
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    children: [
                      for (var i = 0; i < 5; i++)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: SkeletonBox(height: 96, radius: 14),
                        ),
                    ],
                  );
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: '${snapshot.error}',
                    onRetry: _reload,
                  );
                }
                final lists = snapshot.data ?? const [];
                if (lists.isEmpty) {
                  return EmptyState(
                    title: _tab == 'mine'
                        ? 'No lists yet'
                        : 'No public lists',
                    body: _tab == 'mine'
                        ? 'Create a list and add movies and shows from their pages.'
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: lists.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _ListEntry(
                      list: lists[index],
                      showOwner: _tab == 'public',
                      onTap: () {
                        final id = lists[index].i('id');
                        if (id != null) {
                          pushScreen(
                            context,
                            ListDetailScreen(listId: id),
                          ).then((_) => _reload());
                        }
                      },
                      onDelete: _tab == 'mine'
                          ? () async {
                              final id = lists[index].i('id');
                              if (id == null) return;
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete list?'),
                                  content: Text(
                                    'Delete "${lists[index].s('name')}"? This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              try {
                                await ScrobScope.of(context).delete('/lists/$id');
                                _reload();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Could not delete: $e'),
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListEntry extends StatelessWidget {
  const _ListEntry({
    required this.list,
    required this.onTap,
    this.showOwner = false,
    this.onDelete,
  });

  final Map<String, dynamic> list;
  final VoidCallback onTap;
  final bool showOwner;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final previews = list.maps('preview_posters');
    final privacy = list.s('privacy_level') ?? '';
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 80,
                child: previews.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.video_library_outlined,
                          color: kAccentSoft,
                        ),
                      )
                    : Stack(
                        children: [
                          for (var i = previews.length < 3
                                  ? previews.length - 1
                                  : 2;
                              i >= 0;
                              i--)
                            Positioned(
                              left: i * 16.0,
                              top: i * 4.0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      offset: const Offset(2, 0),
                                    ),
                                  ],
                                ),
                                child: SizedBox(
                                  width: 50,
                                  height: 72,
                                  child: Poster(
                                    url: app.imageUrl(
                                      previews[i].s('url'),
                                      size: 'w185',
                                    ),
                                    radius: 6,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (list.b('is_watchlist'))
                          const Padding(
                            padding: EdgeInsets.only(right: 5),
                            child: Icon(
                              Icons.bookmark_rounded,
                              size: 15,
                              color: kAccentSoft,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            list.s('name') ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showOwner && list.s('username') != null)
                      Text(
                        '@${list.s('username')}',
                        style: const TextStyle(fontSize: 11, color: kAccentSoft),
                      ),
                    if (list.s('description') != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          list.s('description')!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: kMuted),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${list.i('item_count') ?? 0} items',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kBody,
                          ),
                        ),
                        if (privacy.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TagChip(label: privacy),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null && !list.b('is_watchlist'))
                PopupMenuButton<String>(
                  iconSize: 18,
                  onSelected: (_) => onDelete!(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete list')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
