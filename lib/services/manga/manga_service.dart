import 'dart:convert';

import '../../core/cache/html_cache.dart';
import '../../core/weebcentral/client.dart';
import '../../core/weebcentral/constants.dart';
import '../../core/weebcentral/parsers.dart';
import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../models/manga/manga_search_filters.dart';

class MangaService {
  MangaService({WeebCentralClient? client, HtmlCache? cache})
      : _client = client ?? weebCentralClient,
        _cache = cache ?? htmlCache;

  final WeebCentralClient _client;
  final HtmlCache _cache;

  Future<MangaItem> fetchManga(String url, {bool forceRefresh = false}) async {
    const ttl = Duration(hours: 6);
    final cacheKey = 'series:$url';
    if (!forceRefresh) {
      final cached = await _cache.read(cacheKey, ttl: ttl);
      if (cached != null) {
        return parseSeriesPage(cached, url);
      }
    }
    final html = await _client.getHtml(Uri.parse(url));
    await _cache.write(cacheKey, html, ttl: ttl);
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

    const ttl = Duration(minutes: 10);
    final cacheKey = 'search:${uri.toString()}';
    final cached = await _cache.read(cacheKey, ttl: ttl);
    if (cached != null) {
      return parseSearchResults(cached);
    }

    final html = await _client.getHtml(uri);
    await _cache.write(cacheKey, html, ttl: ttl);
    return parseSearchResults(html);
  }

  Future<List<ChapterItem>> fetchChapters(
    String mangaId, {
    bool forceRefresh = false,
  }) async {
    const ttl = Duration(minutes: 30);
    final cacheKey = 'chapters:$mangaId';
    if (!forceRefresh) {
      final cached = await _cache.read(cacheKey, ttl: ttl);
      if (cached != null) {
        return parseChapterList(cached);
      }
    }

    final uri = Uri.parse(
      '$weebCentralBaseUrl/series/$mangaId/full-chapter-list',
    );
    final html = await _client.getHtml(uri);
    await _cache.write(cacheKey, html, ttl: ttl);
    return parseChapterList(html);
  }

  Future<List<String>> fetchChapterImages(String chapterId) async {
    const ttl = Duration(hours: 12);
    final cacheKey = 'pages:$chapterId';
    final cached = await _cache.read(cacheKey, ttl: ttl);
    if (cached != null && cached.startsWith('[')) {
      try {
        return List<String>.from(jsonDecode(cached) as List);
      } catch (_) {}
    }

    final uri = Uri.parse(
      '$weebCentralBaseUrl/chapters/$chapterId/images'
      '?is_prev=False&current_page=1&reading_style=long_strip',
    );
    final html = await _client.getHtml(
      uri,
      timeout: const Duration(seconds: 20),
    );
    final pages = parseChapterImages(html);
    await _cache.write(cacheKey, jsonEncode(pages), ttl: ttl);
    return pages;
  }

  Future<List<MangaItem>> getLatestManga() async {
    return searchManga(
      '',
      filters: MangaSearchFilters(
        sort: 'Latest Updates',
        order: 'Descending',
      ),
    );
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
