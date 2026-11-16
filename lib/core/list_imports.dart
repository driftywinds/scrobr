import 'format.dart';

class ListImportSource {
  const ListImportSource(this.id, this.label, this.path, this.hint);

  final String id;
  final String label;
  final String path;
  final String hint;
}

const listImportSources = [
  ListImportSource(
    'tmdb',
    'TMDB list',
    '/lists/import/tmdb',
    'TMDB list ID or themoviedb.org URL',
  ),
  ListImportSource(
    'tvdb',
    'TVDB list',
    '/lists/import/tvdb',
    'TVDB list ID, slug, or thetvdb.com URL',
  ),
  ListImportSource(
    'imdb',
    'IMDb list',
    '/lists/import/imdb',
    'IMDb ls... ID or imdb.com/list URL',
  ),
  ListImportSource(
    'mdblist',
    'MDBList list',
    '/lists/import/mdblist',
    'MDBList ID, slug, or mdblist.com URL',
  ),
];

Map<String, dynamic> listImportBody(String input) => {
      'list_id_or_url': input.trim(),
    };

String? listImportJobId(Map<String, dynamic> response) {
  final job = asMap(response['import']);
  final id = job.s('id');
  return id == null || id.isEmpty ? null : id;
}

bool listImportFinished(Map<String, dynamic> job) {
  final status = job.s('status');
  return status == 'completed' || status == 'failed';
}

String listImportSummary(Map<String, dynamic> job) {
  if (job.s('status') == 'failed') {
    return job.s('error') ?? 'Import failed';
  }
  final added = job.i('added') ?? 0;
  final skipped = job.i('skipped') ?? 0;
  return 'Imported $added item(s)${skipped > 0 ? ', skipped $skipped' : ''}';
}
