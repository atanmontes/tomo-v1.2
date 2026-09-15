import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;

import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import 'constants.dart';
import 'html_utils.dart';

List<MangaItem> parseSearchResults(String html) {
  final document = parser.parse(html);
  final results = <MangaItem>[];
  final seen = <String>{};

  final articles = document.querySelectorAll('body > article');
  final fallback = articles.isEmpty
      ? document.querySelectorAll('article')
      : articles;

  for (final article in fallback) {
    final item = _parseSearchArticle(article);
    if (item == null) continue;
    if (!seen.add(item.id)) continue;
    results.add(item);
  }

  return results;
}

MangaItem? _parseSearchArticle(Element article) {
  final link = article.querySelector('a[href*="/series/"]');
  if (link == null) return null;

  final href = link.attributes['href'];
  if (href == null || href.trim().isEmpty) return null;

  final resultUrl = absoluteWeebUrl(href);
  final id = seriesIdFromUrl(resultUrl);
  if (id == null) return null;

  final detailsSection = article.querySelector('section:nth-child(2)');
  var title = cleanText(detailsSection?.querySelector('a.link')?.text ?? '');

  if (title.isEmpty) {
    final uri = Uri.tryParse(resultUrl);
    title = cleanText((uri?.pathSegments.last ?? '').replaceAll('-', ' '));
  }

  if (title.isEmpty) return null;

  return MangaItem(
    id: id,
    title: title,
    cover: firstCoverCandidate(article) ?? '',
    url: '$weebCentralBaseUrl/series/$id',
    authors: linksByLabels(article, const ['Author(s)', 'Authors', 'Author']),
    tags: linksByLabels(article, const ['Tag(s)', 'Tags(s)', 'Tags', 'Tag']),
    type: valueByLabels(article, const ['Type']),
    status: valueByLabels(article, const ['Status']),
    officialTranslation: boolByLabels(article, const ['Official Translation']),
    animeAdaptation: boolByLabels(article, const ['Anime Adaptation']),
    adultContent: boolByLabels(article, const ['Adult Content']),
  );
}

MangaItem parseSeriesPage(String html, String url) {
  final document = parser.parse(html);
  final id = seriesIdFromUrl(url);
  if (id == null) {
    throw const FormatException('Invalid series URL.');
  }

  var title = cleanText(
    document.querySelector('h1')?.text ??
        document.querySelector('title')?.text ??
        '',
  );

  if (title.contains('|')) {
    title = title.split('|').first.trim();
  }

  return MangaItem(
    id: id,
    title: title.isEmpty ? 'Unknown manga' : title,
    cover: firstCoverCandidate(document.documentElement ?? document.body!) ?? '',
    url: '$weebCentralBaseUrl/series/$id',
    description: _extractDescription(document),
    authors: linksByLabels(document.documentElement ?? document.body!, const [
      'Author(s)',
      'Authors',
      'Author',
    ]),
    tags: linksByLabels(document.documentElement ?? document.body!, const [
      'Tag(s)',
      'Tags(s)',
      'Tags',
      'Tag',
    ]),
    type: valueByLabels(document.documentElement ?? document.body!, const ['Type']),
    status: valueByLabels(document.documentElement ?? document.body!, const [
      'Status',
    ]),
    released: valueByLabels(document.documentElement ?? document.body!, const [
      'Released',
    ]),
    officialTranslation: boolByLabels(
      document.documentElement ?? document.body!,
      const ['Official Translation'],
    ),
    animeAdaptation: boolByLabels(
      document.documentElement ?? document.body!,
      const ['Anime Adaptation'],
    ),
    adultContent: boolByLabels(
      document.documentElement ?? document.body!,
      const ['Adult Content'],
    ),
    associatedNames: linksByLabels(
      document.documentElement ?? document.body!,
      const ['Associated Name(s)', 'Associated Names', 'Alt Name(s)'],
    ),
  );
}

String _extractDescription(Document document) {
  final item = labeledListItem(
    document.documentElement ?? document.body!,
    const ['Description'],
  );

  if (item != null) {
    final strong = item.querySelector('strong');
    var text = cleanText(item.text);
    if (strong != null) {
      text = cleanText(text.replaceFirst(strong.text, ''));
    }
    text = text.replaceFirst(RegExp(r'^:\s*'), '');
    if (text.isNotEmpty) return text;
  }

  for (final element in document.querySelectorAll('strong, h2, h3')) {
    if (normalizeLabel(element.text) != 'description') continue;
    final next = element.nextElementSibling;
    if (next == null) continue;
    final description = cleanText(next.text);
    if (description.isNotEmpty && normalizeLabel(description) != 'description') {
      return description;
    }
  }

  return '';
}

List<ChapterItem> parseChapterList(String html) {
  final document = parser.parse(html);
  final found = <ChapterItem>[];
  final seen = <String>{};

  for (final element in document.querySelectorAll('a[href*="/chapters/"]')) {
    final href = element.attributes['href'];
    if (href == null || href.trim().isEmpty) continue;

    final chapterUrl = absoluteWeebUrl(href);
    final uri = Uri.tryParse(chapterUrl);
    if (uri == null) continue;

    final match = RegExp(
      r'/chapters/([^/]+)',
      caseSensitive: false,
    ).firstMatch(uri.path);
    if (match == null) continue;

    final chapterId = match.group(1)!;
    if (!seen.add(chapterId)) continue;

    final titleSpan = element.querySelector('.grow span');
    final rawText = cleanText(
      titleSpan?.text.isNotEmpty == true ? titleSpan!.text : element.text,
    );

    final title = rawText.isNotEmpty ? rawText : 'Chapter';

    found.add(
      ChapterItem(
        id: chapterId,
        title: title,
        url: chapterUrl,
        number: chapterNumberFromTitle(title),
      ),
    );
  }

  found.sort((a, b) => a.number.compareTo(b.number));
  return found;
}

List<String> parseChapterImages(String html) {
  final document = parser.parse(html);
  final foundImages = <String>[];
  final seen = <String>{};

  for (final image in document.querySelectorAll('img')) {
    final src = image.attributes['src'] ?? image.attributes['data-src'] ?? '';
    if (src.isEmpty) continue;

    final imageUrl = absoluteWeebUrl(src);
    if (imageUrl.contains('/static/') || imageUrl.contains('brand')) {
      continue;
    }

    if (seen.add(imageUrl)) {
      foundImages.add(imageUrl);
    }
  }

  return foundImages;
}
