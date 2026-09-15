import '../../core/weebcentral/client.dart';
import '../../core/weebcentral/constants.dart';
import '../../core/weebcentral/parsers.dart';
import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../models/manga/manga_search_filters.dart';

class MangaService {
  MangaService({WeebCentralClient? client})
      : _client = client ?? WeebCentralClient();

  final WeebCentralClient _client;

  Future<MangaItem> fetchManga(String url) async {
    final html = await _client.getHtml(Uri.parse(url));
    return parseSeriesPage(html, url);
  }

  Future<List<MangaItem>> searchManga(
    String query, {
    MangaSearchFilters filters = const MangaSearchFilters(),
    int offset = 0,
    int limit = 32,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      'text': query.trim(),
      'sort': _sortValue(filters.sort),
      'order': filters.order == 'Ascending' ? 'Ascending' : 'Descending',
      'official': filters.official,
      'anime': filters.animeAdaptation,
      'adult': filters.adultContent,
      'display_mode': 'Full Display',
    };

    final extra = <String>[];
    if (filters.status != 'Any' && filters.status.isNotEmpty) {
      extra.add(
        'included_status=${Uri.encodeQueryComponent(filters.status)}',
      );
    }
    if (filters.type != 'Any' && filters.type.isNotEmpty) {
      extra.add('included_type=${Uri.encodeQueryComponent(filters.type)}');
    }
    extra.addAll(
      filters.tags.map(
        (tag) => 'included_tag=${Uri.encodeQueryComponent(tag)}',
      ),
    );

    final base = Uri.https('weebcentral.com', '/search/data', params);
    final uri = extra.isEmpty
        ? base
        : Uri.parse('${base.toString()}&${extra.join('&')}');

    final html = await _client.getHtml(uri);
    return parseSearchResults(html);
  }

  Future<List<ChapterItem>> fetchChapters(String mangaId) async {
    final uri = Uri.parse(
      '$weebCentralBaseUrl/series/$mangaId/full-chapter-list',
    );
    final html = await _client.getHtml(uri);
    return parseChapterList(html);
  }

  Future<List<String>> fetchChapterImages(String chapterId) async {
    final uri = Uri.parse(
      '$weebCentralBaseUrl/chapters/$chapterId/images'
      '?is_prev=False&current_page=1&reading_style=long_strip',
    );
    final html = await _client.getHtml(
      uri,
      timeout: const Duration(seconds: 20),
    );
    return parseChapterImages(html);
  }

  String _sortValue(String value) {
    switch (value) {
      case 'Alphabet':
      case 'Popularity':
      case 'Subscribers':
      case 'Recently Added':
      case 'Latest Updates':
      case 'Best Match':
        return value;
      default:
        return 'Best Match';
    }
  }
}
