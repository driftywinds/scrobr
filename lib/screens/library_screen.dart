import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/genres.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _scroll = ScrollController();
  String _type = 'movie';
  _Filters _filters = const _Filters();
  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load(reset: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && _page > _totalPages) return;
    setState(() {
      _loading = true;
      if (reset) {
        _page = 1;
        _totalPages = 1;
        _items.clear();
        _error = null;
      }
    });
    final app = ScrobScope.of(context);
    final query = <String, dynamic>{
      'page': _page,
      'page_size': 30,
      'sort': _filters.sort,
    };
    if (_type == 'movie') query['type'] = 'movie';
    if (_filters.watched != null) query['watched'] = [_filters.watched!];
    if (_filters.rating != null) query['my_rating'] = [_filters.rating!];
    if (_filters.inList != null) query['in_list'] = _filters.inList;
    if (_filters.year != null) query['year'] = [_filters.year!];
    if (_filters.genres.isNotEmpty) query['genre'] = _filters.genres.toList();

    try {
      final result = await app.get(_type == 'movie' ? '/media' : '/shows', query);
      final data = asMap(result);
      final results = data.maps('results');
      if (!mounted) return;
      setState(() {
        _items.addAll(results);
        _totalPages = data.i('total_pages') ?? 1;
        _page += 1;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _filters, type: _type),
    );
    if (result == null) return;
    setState(() => _filters = result);
    _load(reset: true);
  }

  void _switchType(String value) {
    if (value == _type) return;
    setState(() {
      _type = value;
      _filters = const _Filters();
      _items.clear();
      _page = 1;
      _totalPages = 1;
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final activeFilters = _filters.count +
        (_filters.sort == 'created_at' ? 0 : 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Explore',
            onPressed: () => openExplore(context, type: _type),
            icon: const Icon(Icons.explore_outlined),
          ),
          IconButton(
            onPressed: () => openSearch(context),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: activeFilters > 0,
              label: Text('$activeFilters'),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: SegmentedTabs<String>(segments: const [
                ButtonSegment(value: 'movie', label: Text('Movies')),
                ButtonSegment(value: 'series', label: Text('Shows')),
              ],
              selected: {_type},
              onSelectionChanged: (value) => _switchType(value.first),
            ),
          ),
          if (_filters.count > 0 || _filters.sort != 'created_at')
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_rounded, size: 15, color: kAccentSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _filters.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kBody),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _filters = const _Filters());
                      _load(reset: true);
                    },
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty && _loading) {
      return const PosterGridSkeleton();
    }
    if (_items.isEmpty && _error != null) {
      return ListView(
        children: [
          ErrorView(message: _error!, onRetry: () => _load(reset: true)),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: [
          EmptyState(
            title: _type == 'movie'
                ? 'Your movie library is empty'
                : 'Your show library is empty',
            body:
                'Connect a media server in Settings and run a sync, or add titles from Discover.',
          ),
        ],
      );
    }
    return GridView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
        childAspectRatio: 0.50,
      ),
      itemCount: _items.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final item = _items[index];
        return LayoutBuilder(
          builder: (context, constraints) => MediaCard(
            item: item,
            width: constraints.maxWidth,
          ),
        );
      },
    );
  }
}

class _Filters {
  const _Filters({
    this.sort = 'created_at',
    this.watched,
    this.rating,
    this.inList,
    this.year,
    this.genres = const {},
  });

  final String sort;
  final String? watched;
  final int? rating;
  final String? inList;
  final int? year;
  final Set<String> genres;

  int get count =>
      (watched == null ? 0 : 1) +
      (rating == null ? 0 : 1) +
      (inList == null ? 0 : 1) +
      (year == null ? 0 : 1) +
      genres.length;

  String get summary {
    final parts = <String>[];
    if (watched != null) parts.add(watched == 'watched' ? 'Watched' : 'Unwatched');
    if (rating != null) parts.add('Rated $rating');
    if (inList != null) parts.add(inList == 'in' ? 'In a list' : 'Not in a list');
    if (year != null) parts.add('$year');
    parts.addAll(genres);
    if (sort != 'created_at') parts.add(_sortLabel(sort));
    return parts.join(' · ');
  }

  _Filters copyWith({
    String? sort,
    String? watched,
    bool clearWatched = false,
    int? rating,
    bool clearRating = false,
    String? inList,
    bool clearInList = false,
    int? year,
    bool clearYear = false,
    Set<String>? genres,
  }) {
    return _Filters(
      sort: sort ?? this.sort,
      watched: clearWatched ? null : (watched ?? this.watched),
      rating: clearRating ? null : (rating ?? this.rating),
      inList: clearInList ? null : (inList ?? this.inList),
      year: clearYear ? null : (year ?? this.year),
      genres: genres ?? this.genres,
    );
  }
}

const _sorts = {
  'created_at': 'Recently added',
  'title': 'Title A-Z',
  'release_date': 'Release date',
  'rating': 'TMDB rating',
  'user_rating': 'My rating',
  'last_watched': 'Last watched',
};

String _sortLabel(String key) => _sorts[key] ?? key;

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.type});

  final _Filters initial;
  final String type;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _Filters _value = widget.initial;
  late final _year = TextEditingController(
    text: widget.initial.year?.toString() ?? '',
  );
  List<Map<String, dynamic>> _saved = [];
  bool _savedLoaded = false;

  List<String> get _genres =>
      widget.type == 'movie' ? movieGenres : showGenres;

  String get _scope => widget.type == 'movie' ? '/movies' : '/shows';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_savedLoaded) {
      _savedLoaded = true;
      _loadSaved();
    }
  }

  Future<void> _loadSaved() async {
    try {
      final data =
          await ScrobScope.of(context).get('/saved-filters', {'scope': _scope});
      if (!mounted) return;
      setState(() => _saved = asMaps(data));
    } catch (_) {
      // Saved filters are optional and JWT-only; API-key mode hides them.
    }
  }

  String? _firstParam(Map<String, dynamic> params, String key) {
    final values = asStrings(params[key]);
    return values.isEmpty ? null : values.first;
  }

  _Filters _valueFromParams(Map<String, dynamic> params) {
    return _Filters(
      sort: _value.sort,
      watched: _firstParam(params, 'watched'),
      rating: int.tryParse(_firstParam(params, 'my_rating') ?? ''),
      inList: _firstParam(params, 'in_list'),
      year: int.tryParse(_firstParam(params, 'year') ?? ''),
      genres: asStrings(params['genre']).toSet(),
    );
  }

  Map<String, List<String>> _currentParams() {
    final year = int.tryParse(_year.text.trim()) ?? _value.year;
    return {
      if (_value.watched != null) 'watched': [_value.watched!],
      if (_value.rating != null) 'my_rating': ['${_value.rating}'],
      if (_value.inList != null) 'in_list': [_value.inList!],
      if (year != null) 'year': ['$year'],
      if (_value.genres.isNotEmpty) 'genre': _value.genres.toList(),
    };
  }

  Future<void> _saveCurrent() async {
    final params = _currentParams();
    if (params.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one filter first')),
      );
      return;
    }
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save filters'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await ScrobScope.of(context).post('/saved-filters', {
        'scope': _scope,
        'name': name,
        'params': params,
      });
      await _loadSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save filters: $e')),
        );
      }
    }
  }

  Future<void> _deleteSaved(int id) async {
    try {
      await ScrobScope.of(context).delete('/saved-filters/$id');
      await _loadSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete filter: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filters',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _value = const _Filters()),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_saved.isNotEmpty) ...[
              const Text(
                'Saved filters',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: _saved.map((saved) {
                  return InputChip(
                    label: Text(
                      saved.s('name') ?? '',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      final next =
                          _valueFromParams(asMap(saved['params']));
                      setState(() {
                        _value = next;
                        _year.text = next.year?.toString() ?? '';
                      });
                    },
                    onDeleted: () {
                      final id = saved.i('id');
                      if (id != null) _deleteSaved(id);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saveCurrent,
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const Text(
                  'Save current filters',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Sort', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _value.sort,
              items: _sorts.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _value = _value.copyWith(sort: v)),
            ),
            const SizedBox(height: 16),
            const Text('Watched', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any'),
                  selected: _value.watched == null,
                  onSelected: (_) => setState(
                    () => _value = _value.copyWith(clearWatched: true),
                  ),
                ),
                ChoiceChip(
                  label: const Text('Watched'),
                  selected: _value.watched == 'watched',
                  onSelected: (_) => setState(
                    () => _value = _value.copyWith(watched: 'watched'),
                  ),
                ),
                ChoiceChip(
                  label: const Text('Unwatched'),
                  selected: _value.watched == 'unwatched',
                  onSelected: (_) => setState(
                    () => _value = _value.copyWith(watched: 'unwatched'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('My rating', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int?>(
              initialValue: _value.rating,
              items: [
                const DropdownMenuItem(value: null, child: Text('Any rating')),
                ...List.generate(
                  10,
                  (i) => DropdownMenuItem(
                    value: 10 - i,
                    child: Text('${10 - i} / 10'),
                  ),
                ),
              ],
              onChanged: (v) => setState(
                () => _value = v == null
                    ? _value.copyWith(clearRating: true)
                    : _value.copyWith(rating: v),
              ),
            ),
            const SizedBox(height: 16),
            const Text('List membership', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any'),
                  selected: _value.inList == null,
                  onSelected: (_) => setState(
                    () => _value = _value.copyWith(clearInList: true),
                  ),
                ),
                ChoiceChip(
                  label: const Text('In a list'),
                  selected: _value.inList == 'in',
                  onSelected: (_) => setState(
                    () => _value = _value.copyWith(inList: 'in'),
                  ),
                ),
                ChoiceChip(
                  label: const Text('Not in a list'),
                  selected: _value.inList == 'out',
                  onSelected: (_) => setState(
                    () => _value = _value.copyWith(inList: 'out'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Year',
                hintText: 'Any year',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Genres', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: _genres
                  .map(
                    (g) => FilterChip(
                      label: Text(g, style: const TextStyle(fontSize: 11)),
                      selected: _value.genres.contains(g),
                      onSelected: (on) {
                        final next = {..._value.genres};
                        on ? next.add(g) : next.remove(g);
                        setState(() => _value = _value.copyWith(genres: next));
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                final year = int.tryParse(_year.text.trim());
                Navigator.pop(
                  context,
                  year == null
                      ? _value.copyWith(clearYear: true)
                      : _value.copyWith(year: year),
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}
