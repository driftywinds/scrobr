import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen._({
    required this.title,
    this.path,
    this.query = const {},
    this.collectionId,
    this.singlePage = false,
  });

  static BrowseScreen trending({required String type}) => BrowseScreen._(
        title: type == 'movie' ? 'Trending Movies' : 'Trending Shows',
        path: type == 'movie' ? '/media/trending/movies' : '/media/trending/shows',
      );

  static BrowseScreen topRated({required String type}) => BrowseScreen._(
        title: type == 'movie' ? 'Top Rated Movies' : 'Top Rated Shows',
        path: type == 'movie' ? '/media/top-rated-movies' : '/media/top-rated-shows',
      );

  static BrowseScreen recentlyAdded({required String type}) => BrowseScreen._(
        title: type == 'movie' ? 'Recently Added Movies' : 'Recently Added Episodes',
        path: '/media/recently-added',
        query: {'type': type, 'limit': 60},
        singlePage: true,
      );

  static BrowseScreen airingToday() => BrowseScreen._(
        title: 'Airing Today',
        path: '/media/airing-today/collected',
        singlePage: true,
      );

  static BrowseScreen collection(int id) => BrowseScreen._(
        title: 'Collection',
        collectionId: id,
        singlePage: true,
      );

  final String title;
  final String? path;
  final Map<String, dynamic> query;
  final int? collectionId;
  final bool singlePage;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _header;
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
    if (!widget.singlePage && !reset && _page > _totalPages) return;
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
    try {
      if (widget.collectionId != null) {
        final data = asMap(
          await app.get('/media/collection/${widget.collectionId}'),
        );
        if (!mounted) return;
        setState(() {
          _header = data;
          _items
            ..clear()
            ..addAll(data.maps('parts'));
          _totalPages = 1;
        });
      } else {
        final query = <String, dynamic>{...widget.query};
        if (!widget.singlePage) query['page'] = _page;
        final data = asMap(await app.get(widget.path!, query));
        if (!mounted) return;
        setState(() {
          _items.addAll(data.maps('results'));
          _totalPages = data.i('total_pages') ?? 1;
          _page += 1;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty && _loading) {
      return const LoadingView();
    }
    if (_items.isEmpty && _error != null) {
      return ListView(
        children: [
          ErrorView(message: _error!, onRetry: () => _load(reset: true)),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(children: const [EmptyState(title: 'Nothing here yet')]);
    }
    final grid = SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
        childAspectRatio: 0.50,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
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
        childCount: _items.length + (_loading && !widget.singlePage ? 1 : 0),
      ),
    );

    if (_header != null) {
      return CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(child: _CollectionHeader(data: _header!)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            sliver: grid,
          ),
        ],
      );
    }
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          sliver: grid,
        ),
      ],
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final backdrop = app.imageUrl(data.s('backdrop_path'), size: 'w780');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (backdrop != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  backdrop,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: kCard),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            data.s('name') ?? 'Collection',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          if (data.s('overview') != null) ...[
            const SizedBox(height: 6),
            Text(
              data.s('overview')!,
              style: const TextStyle(color: kMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
