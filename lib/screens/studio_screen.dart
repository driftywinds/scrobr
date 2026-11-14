import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    required this.id,
    required this.isNetwork,
  });

  final int id;
  final bool isNetwork;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _header;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _started = false;
  String? _error;

  String get _headerPath =>
      widget.isNetwork ? '/media/network/${widget.id}' : '/media/company/${widget.id}';

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
    try {
      final futures = <Future<dynamic>>[
        if (_header == null) app.get(_headerPath),
        app.get('/media/tmdb/list', {
          'type': widget.isNetwork ? 'series' : 'movie',
          if (widget.isNetwork) 'network': widget.id else 'company': widget.id,
          'page': _page,
        }),
      ];
      final results = await Future.wait(futures);
      final list = asMap(results.last);
      if (!mounted) return;
      setState(() {
        if (_header == null) _header = asMap(results.first);
        _items.addAll(list.maps('results'));
        _totalPages = list.i('total_pages') ?? 1;
        _page += 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = _header;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          header?.s('name') ??
              (widget.isNetwork ? 'Network' : 'Studio'),
        ),
      ),
      body: _items.isEmpty && _loading
          ? const LoadingView()
          : _items.isEmpty && _error != null
              ? ErrorView(
                  message: _error!,
                  onRetry: () => _load(reset: true),
                )
              : CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    if (header != null)
                      SliverToBoxAdapter(
                        child: _StudioHeader(header: header),
                      ),
                    SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
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
                        childCount:
                            _items.length + (_loading ? 1 : 0),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
    );
  }
}

class _StudioHeader extends StatelessWidget {
  const _StudioHeader({required this.header});

  final Map<String, dynamic> header;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final logo = app.imageUrl(header.s('logo_path'), size: 'w185');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: logo == null
                ? const Icon(Icons.apartment_rounded, color: kMuted, size: 42)
                : Image.network(
                    logo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.apartment_rounded,
                      color: kMuted,
                      size: 42,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  header.s('name') ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (header.s('origin_country') != null)
                  Text(
                    header.s('origin_country')!,
                    style: const TextStyle(fontSize: 11, color: kMuted),
                  ),
                if (header.s('homepage') != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => launchUrl(
                      Uri.parse(header.s('homepage')!),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text(
                      'Homepage',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
