import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/genres.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.initialType = 'movie'});

  final String initialType;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  late String _type = widget.initialType;
  String _category = 'popular';
  _ExploreFilters _filters = const _ExploreFilters();
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
    try {
      final data = asMap(await ScrobScope.of(context).get('/media/tmdb/list', {
        'type': _type,
        'category': _category,
        'page': _page,
        if (_filters.genres.isNotEmpty) 'genre': _filters.genres.toList(),
        if (_filters.year != null) 'year': [_filters.year!],
        if (_filters.minRating != null) 'min_rating': _filters.minRating,
        if (_filters.watch != null) 'watch': [_filters.watch!],
        if (_filters.inList != null) 'in_list': [_filters.inList!],
        if (_filters.myRating != null) 'my_rating': [_filters.myRating!],
      }));
      if (!mounted) return;
      setState(() {
        _items.addAll(data.maps('results'));
        _totalPages = data.i('total_pages') ?? 1;
        _page += 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setType(String value) {
    if (value == _type) return;
    setState(() {
      _type = value;
      _filters = const _ExploreFilters();
    });
    _load(reset: true);
  }

  void _setCategory(String value) {
    if (value == _category) return;
    setState(() => _category = value);
    _load(reset: true);
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_ExploreFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExploreFilterSheet(
        initial: _filters,
        type: _type,
      ),
    );
    if (result == null) return;
    setState(() => _filters = result);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _filters.count > 0,
              label: Text('${_filters.count}'),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: SegmentedTabs<String>(segments: const [
                ButtonSegment(value: 'movie', label: Text('Movies')),
                ButtonSegment(value: 'series', label: Text('Shows')),
              ],
              selected: {_type},
              onSelectionChanged: (value) => _setType(value.first),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final entry in const {
                  'popular': 'Popular',
                  'top_rated': 'Top rated',
                  'trending': 'Trending',
                }.entries) ...[
                  ChoiceChip(
                    label: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: _category == entry.key,
                    onSelected: (_) => _setCategory(entry.key),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          if (_filters.count > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _filters.summary(_type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: kMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _filters = const _ExploreFilters());
                      _load(reset: true);
                    },
                    child: const Text('Clear', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_items.isEmpty && _loading) {
      return const LoadingView();
    }
    if (_items.isEmpty && _error != null) {
      return ListView(
        children: [ErrorView(message: _error!, onRetry: () => _load(reset: true))],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: const [
          EmptyState(
            title: 'Nothing found',
            body: 'Try another category or clear some filters.',
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: GridView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
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
      ),
    );
  }
}

class _ExploreFilters {
  const _ExploreFilters({
    this.genres = const {},
    this.year,
    this.minRating,
    this.watch,
    this.inList,
    this.myRating,
  });

  final Set<String> genres;
  final int? year;
  final double? minRating;
  final String? watch;
  final String? inList;
  final int? myRating;

  int get count =>
      genres.length +
      (year == null ? 0 : 1) +
      (minRating == null ? 0 : 1) +
      (watch == null ? 0 : 1) +
      (inList == null ? 0 : 1) +
      (myRating == null ? 0 : 1);

  String summary(String type) {
    final parts = <String>[];
    if (watch != null) parts.add(watch == 'watched' ? 'Watched' : 'Unwatched');
    if (inList != null) parts.add(inList == 'in' ? 'In a list' : 'Not in a list');
    if (myRating != null) parts.add('My rating $myRating');
    if (minRating != null) parts.add('${minRating!.toStringAsFixed(0)}+ rating');
    if (year != null) parts.add('$year');
    parts.addAll(genres);
    return parts.join(' · ');
  }
}

class _ExploreFilterSheet extends StatefulWidget {
  const _ExploreFilterSheet({required this.initial, required this.type});

  final _ExploreFilters initial;
  final String type;

  @override
  State<_ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<_ExploreFilterSheet> {
  late Set<String> _genres = {...widget.initial.genres};
  late int? _year = widget.initial.year;
  late double? _minRating = widget.initial.minRating;
  late String? _watch = widget.initial.watch;
  late String? _inList = widget.initial.inList;
  late int? _myRating = widget.initial.myRating;
  late final _yearController =
      TextEditingController(text: _year?.toString() ?? '');

  List<String> get _genresList =>
      widget.type == 'movie' ? movieGenres : showGenres;

  @override
  void dispose() {
    _yearController.dispose();
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
                    'Explore filters',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _genres = {};
                    _year = null;
                    _minRating = null;
                    _watch = null;
                    _inList = null;
                    _myRating = null;
                    _yearController.clear();
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const Text('Watched', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any'),
                  selected: _watch == null,
                  onSelected: (_) => setState(() => _watch = null),
                ),
                ChoiceChip(
                  label: const Text('Watched'),
                  selected: _watch == 'watched',
                  onSelected: (_) => setState(() => _watch = 'watched'),
                ),
                ChoiceChip(
                  label: const Text('Unwatched'),
                  selected: _watch == 'unwatched',
                  onSelected: (_) => setState(() => _watch = 'unwatched'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<double?>(
                    initialValue: _minRating,
                    decoration: const InputDecoration(labelText: 'Min rating'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Any')),
                      DropdownMenuItem(value: 5, child: Text('5+')),
                      DropdownMenuItem(value: 6, child: Text('6+')),
                      DropdownMenuItem(value: 7, child: Text('7+')),
                      DropdownMenuItem(value: 8, child: Text('8+')),
                      DropdownMenuItem(value: 9, child: Text('9+')),
                    ],
                    onChanged: (v) => setState(() => _minRating = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year'),
                    onChanged: (v) =>
                        setState(() => _year = int.tryParse(v.trim())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _myRating,
                    decoration: const InputDecoration(labelText: 'My rating'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Any')),
                      ...List.generate(
                        10,
                        (i) => DropdownMenuItem(
                          value: 10 - i,
                          child: Text('${10 - i} / 10'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _myRating = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _inList,
                    decoration: const InputDecoration(labelText: 'List'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Any')),
                      DropdownMenuItem(value: 'in', child: Text('In a list')),
                      DropdownMenuItem(value: 'out', child: Text('Not in a list')),
                    ],
                    onChanged: (v) => setState(() => _inList = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Genres', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: _genresList.map((genre) {
                return FilterChip(
                  label: Text(genre, style: const TextStyle(fontSize: 11)),
                  selected: _genres.contains(genre),
                  onSelected: (on) => setState(() {
                    on ? _genres.add(genre) : _genres.remove(genre);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _ExploreFilters(
                    genres: _genres,
                    year: _year,
                    minRating: _minRating,
                    watch: _watch,
                    inList: _inList,
                    myRating: _myRating,
                  ),
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
