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
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'movie', label: Text('Movies')),
                ButtonSegment(value: 'series', label: Text('Shows')),
              ],
              selected: {_type},
              onSelectionChanged: (value) => _switchType(value.first),
            ),
          ),
          if (_filters.count > 0 || _filters.sort != 'created_at')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, size: 14, color: kMuted),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _filters.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: kMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _filters = const _Filters());
                      _load(reset: true);
                    },
                    child: const Text('Clear', style: TextStyle(fontSize: 11)),
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
      return const LoadingView(label: 'Loading your library');
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

  List<String> get _genres =>
      widget.type == 'movie' ? movieGenres : showGenres;

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
