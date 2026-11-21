import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/list_sort.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({super.key, required this.listId});

  final int listId;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  Future<Map<String, dynamic>>? _future;
  ListSort _sort = ListSort.added;
  int _randomSeed = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() async =>
      asMap(await ScrobScope.of(context).get('/lists/${widget.listId}'));

  void _reload() => setState(() => _future = _load());

  Future<void> _edit(Map<String, dynamic> list) async {
    final name = TextEditingController(text: list.s('name'));
    final description = TextEditingController(text: list.s('description'));
    final isWatchlist = list.b('is_watchlist');
    var privacy = list.s('privacy_level') ?? 'private';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit list'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  readOnly: isWatchlist,
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
                  onChanged: isWatchlist
                      ? null
                      : (v) => setState(() => privacy = v ?? 'private'),
                  decoration: const InputDecoration(labelText: 'Privacy'),
                ),
                if (isWatchlist)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'The watchlist is always private.',
                      style: TextStyle(fontSize: 12, color: kMuted),
                    ),
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
    if (ok != true) {
      name.dispose();
      description.dispose();
      return;
    }
    try {
      final body = <String, dynamic>{
        'name': name.text.trim(),
        'description': description.text.trim().isEmpty
            ? null
            : description.text.trim(),
      };
      if (!isWatchlist) body['privacy_level'] = privacy;
      await ScrobScope.of(context).patch('/lists/${widget.listId}', body);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update list: $e')),
        );
      }
    } finally {
      name.dispose();
      description.dispose();
    }
  }

  Future<void> _deleteList() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ScrobScope.of(context).delete('/lists/${widget.listId}');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete list: $e')),
        );
      }
    }
  }

  Future<void> _removeItem(int itemId) async {
    try {
      await ScrobScope.of(context)
          .delete('/lists/${widget.listId}/items/$itemId');
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('List'),
        actions: [
          PopupMenuButton<ListSort>(
            tooltip: 'Sort list',
            icon: const Icon(Icons.sort_rounded),
            onSelected: (value) => setState(() {
              _sort = value;
              _randomSeed = DateTime.now().microsecondsSinceEpoch;
            }),
            itemBuilder: (_) => [
              for (final option in listSortOptions)
                PopupMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: option == _sort
                            ? const Icon(Icons.check_rounded, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Text(option.label),
                    ],
                  ),
                ),
            ],
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              final list = snapshot.data;
              if (list == null || !list.b('is_owner')) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _edit(list);
                  if (value == 'delete' && !list.b('is_watchlist')) {
                    _deleteList();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit list')),
                  if (!list.b('is_watchlist'))
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete list'),
                    ),
                ],
              );
            },
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
          final list = snapshot.data ?? const {};
          final items = sortListItems(
            list.maps('items'),
            sort: _sort,
            randomSeed: _randomSeed,
          );
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.s('name') ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (list.s('description') != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          list.s('description')!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: kMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${list.i('item_count') ?? items.length} items · ${list.s('privacy_level') ?? ''} · ${_sort.label}',
                        style: const TextStyle(fontSize: 11, color: kMuted),
                      ),
                    ],
                  ),
                ),
                if (items.isEmpty)
                  const EmptyState(
                    title: 'This list is empty',
                    body: 'Open a movie or show and use "Add to list".',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.50,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final entry = items[index];
                      final media = asMap(entry['media']);
                      return GestureDetector(
                        onLongPress: list.b('is_owner')
                            ? () => _confirmRemove(entry)
                            : null,
                        child: LayoutBuilder(
                          builder: (context, constraints) => MediaCard(
                            item: media,
                            width: constraints.maxWidth,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(Map<String, dynamic> entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from list?'),
        content: Text(asMap(entry['media']).s('title') ?? ''),
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
    if (ok == true) {
      final id = entry.i('id');
      if (id != null) _removeItem(id);
    }
  }
}

