import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String _status = 'pending';
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await ScrobScope.of(context).get('/admin/requests');
    return asMaps(data);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _act(int id, bool approve) async {
    try {
      await ScrobScope.of(context).post(
        '/admin/requests/$id/${approve ? 'approve' : 'reject'}',
      );
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    if (!app.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Requests')),
        body: const EmptyState(
          title: 'Admin access required',
          body: 'Only admins can review media requests.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SegmentedButton<String>(showSelectedIcon: false, 
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Pending')),
                ButtonSegment(value: 'approved', label: Text('Approved')),
                ButtonSegment(value: 'rejected', label: Text('Rejected')),
              ],
              selected: {_status},
              onSelectionChanged: (value) {
                setState(() => _status = value.first);
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
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
                final requests = (snapshot.data ?? const [])
                    .where((r) => r.s('status') == _status)
                    .toList();
                if (requests.isEmpty) {
                  return EmptyState(
                    title: 'No $_status requests',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final user = asMap(request['user']);
                      final poster = app.imageUrl(
                        request.s('poster_path'),
                        size: 'w185',
                      );
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              height: 72,
                              child: Poster(
                                url: poster,
                                title: request.s('title'),
                                radius: 7,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request.s('title') ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${request.s('media_type')} · ${user.s('display_name') ?? user.s('username') ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: kMuted,
                                    ),
                                  ),
                                  Text(
                                    fmtDate(request.s('created_at')),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: kMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_status == 'pending') ...[
                              TextButton(
                                onPressed: () {
                                  final id = request.i('id');
                                  if (id != null) _act(id, true);
                                },
                                child: const Text(
                                  'Approve',
                                  style: TextStyle(color: kGreen),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  final id = request.i('id');
                                  if (id != null) _act(id, false);
                                },
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(color: kDanger),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
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
