import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../widgets/common.dart';
import '../core/friendly_error.dart';

class ProfileMediaScreen extends StatefulWidget {
  const ProfileMediaScreen({
    super.key,
    required this.userId,
    required this.kind,
    required this.title,
  });

  final int userId;
  final String kind;
  final String title;

  @override
  State<ProfileMediaScreen> createState() => _ProfileMediaScreenState();
}

class _ProfileMediaScreenState extends State<ProfileMediaScreen> {
  final _scroll = ScrollController();
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
    try {
      final data = asMap(await ScrobScope.of(context).get(
        '/profile/${widget.userId}/${widget.kind}',
        {'page': _page},
      ));
      if (!mounted) return;
      setState(() {
        _items.addAll(data.maps('results'));
        _totalPages = data.i('total_pages') ?? 1;
        _page += 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _asMedia(Map<String, dynamic> item) {
    final type = item.s('media_type') ?? item.s('type') ?? 'movie';
    return {
      ...item,
      'type': type == 'show' ? 'series' : type,
      'title': item.s('title') ?? '',
    };
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
        children: [ErrorView(message: _error!, onRetry: () => _load(reset: true))],
      );
    }
    if (_items.isEmpty) {
      return ListView(children: const [EmptyState(title: 'Nothing here yet')]);
    }
    return GridView.builder(
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
        final item = _asMedia(_items[index]);
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
