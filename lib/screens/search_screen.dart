import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _type = 'movie';
  String _query = '';
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      if (q.length < 2) return;
      if (q == _query) return;
      _query = q;
      _search(reset: true);
    });
  }

  Future<void> _search({bool reset = false}) async {
    if (_query.isEmpty) return;
    if (_loading) return;
    if (!reset && _page > _totalPages) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _totalPages = 1;
        _results = [];
        _users = [];
      }
    });
    final app = ScrobScope.of(context);
    try {
      if (_type == 'user') {
        final data = asMap(
          await app.get('/profile/search', {'q': _query}),
        );
        if (!mounted) return;
        setState(() {
          _users = data.maps('results');
          _totalPages = 1;
        });
      } else {
        final data = asMap(await app.get('/media/search', {
          'q': _query,
          'type': _type,
          'page': _page,
        }));
        if (!mounted) return;
        setState(() {
          _results.addAll(data.maps('results'));
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

  void _loadMore() {
    if (_type == 'user') return;
    if (!_loading && _page <= _totalPages && _query.isNotEmpty) {
      _search();
    }
  }

  void _setType(String value) {
    if (value == _type) return;
    setState(() {
      _type = value;
      _results = [];
      _users = [];
      _page = 1;
      _totalPages = 1;
      _error = null;
    });
    if (_query.isNotEmpty) _search(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onChanged,
          onSubmitted: (v) {
            _query = v.trim();
            _search(reset: true);
          },
          decoration: InputDecoration(
            hintText: _type == 'user' ? 'Search people' : 'Search movies, shows, people',
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _query = '';
                        _results = [];
                        _users = [];
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(showSelectedIcon: false, 
                segments: const [
                  ButtonSegment(value: 'movie', label: Text('Movies')),
                  ButtonSegment(value: 'series', label: Text('Shows')),
                  ButtonSegment(value: 'person', label: Text('People')),
                  ButtonSegment(value: 'user', label: Text('Users')),
                ],
                selected: {_type},
                onSelectionChanged: (value) => _setType(value.first),
              ),
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_query.isEmpty) {
      return const EmptyState(
        title: 'Find something to watch',
        body: 'Search TMDB for movies, shows and people, or find other Scrob users.',
        icon: Icons.search_rounded,
      );
    }
    if (_loading && _results.isEmpty && _users.isEmpty) {
      return const LoadingView(label: 'Searching');
    }
    if (_error != null && _results.isEmpty && _users.isEmpty) {
      return ErrorView(message: _error!, onRetry: () => _search(reset: true));
    }

    if (_type == 'user') {
      if (_users.isEmpty) {
        return const EmptyState(title: 'No users found');
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = _users[index];
          final avatar = ScrobScope.of(context).imageUrl(user.s('avatar_url'));
          return ListTile(
            leading: UserAvatar(
              url: avatar,
              name: user.s('display_name') ?? user.s('username'),
              size: 42,
            ),
            title: Text(
              user.s('display_name') ?? user.s('username') ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '@${user.s('username') ?? ''}',
              style: const TextStyle(color: kMuted, fontSize: 11),
            ),
            onTap: () {
              final id = user.i('id');
              if (id != null) openProfile(context, id);
            },
          );
        },
      );
    }

    if (_results.isEmpty) {
      return const EmptyState(title: 'No results');
    }
    if (_type == 'person') {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final person = _results[index];
          final avatar = ScrobScope.of(context)
              .imageUrl(person.s('poster_path'), size: 'w185');
          return ListTile(
            leading: UserAvatar(
              url: avatar,
              name: person.s('title'),
              size: 48,
            ),
            title: Text(
              person.s('title') ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              person.s('known_for_department') ?? 'Person',
              style: const TextStyle(color: kMuted, fontSize: 11),
            ),
            onTap: () {
              final id = person.i('tmdb_id');
              if (id != null) openPerson(context, id);
            },
          );
        },
      );
    }

    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
        childAspectRatio: 0.50,
      ),
      itemCount: _results.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final item = _results[index];
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
