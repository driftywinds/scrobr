import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../core/friendly_error.dart';

class PersonScreen extends StatefulWidget {
  const PersonScreen({super.key, required this.personId});

  final int personId;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  final List<Map<String, dynamic>> _credits = [];
  Map<String, dynamic>? _person;
  int _page = 1;
  int _totalCredits = 0;
  bool _loading = false;
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final data = asMap(await ScrobScope.of(context).get(
        '/media/person/${widget.personId}',
        {'page': _page},
      ));
      if (!mounted) return;
      setState(() {
        _person = data;
        _credits.addAll(data.maps('credits'));
        _totalCredits = data.i('total_credits') ?? _credits.length;
        _page += 1;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final person = _person;
    if (person == null && _loading) {
      return const Scaffold(body: LoadingView());
    }
    if (person == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: _error ?? 'Person not found', onRetry: _load),
      );
    }
    final photo = app.imageUrl(person.s('profile_path'), size: 'w342');
    final credits = _credits;
    return Scaffold(
      appBar: AppBar(title: Text(person.s('name') ?? 'Person')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  height: 150,
                  child: UserAvatar(
                    url: photo,
                    name: person.s('name'),
                    size: 110,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.s('name') ?? '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (person.s('known_for_department') != null)
                        Text(
                          person.s('known_for_department')!,
                          style: TextStyle(
                            fontSize: 12,
                            color: kAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (person.s('birthday') != null)
                        Text(
                          'Born ${fmtDate(person.s('birthday'))}',
                          style: const TextStyle(fontSize: 11, color: kMuted),
                        ),
                      if (person.s('place_of_birth') != null)
                        Text(
                          person.s('place_of_birth')!,
                          style: const TextStyle(fontSize: 11, color: kMuted),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '${credits.length} of $_totalCredits credits',
                        style: const TextStyle(fontSize: 11, color: kMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (person.s('biography') != null && person.s('biography')!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Biography',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  Text(
                    person.s('biography')!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFFD4D4D8),
                    ),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Credits',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.48,
            ),
            itemCount: credits.length,
            itemBuilder: (context, index) {
              final credit = credits[index];
              return LayoutBuilder(
                builder: (context, constraints) => MediaCard(
                  item: {
                    ...credit,
                    'type': credit.s('type') == 'series' ? 'series' : 'movie',
                    'release_date': credit.s('release_date'),
                    'poster_path': credit.s('poster_path'),
                  },
                  width: constraints.maxWidth,
                  showSubtitle: true,
                ),
              );
            },
          ),
          if (_credits.length < _totalCredits)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.tonal(
                onPressed: _loading ? null : _load,
                child: Text(_loading ? 'Loading…' : 'Load more credits'),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: kDanger, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
