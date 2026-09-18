import 'package:html/dom.dart';

import 'constants.dart';

String cleanText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String absoluteWeebUrl(String url) {
  if (url.isEmpty) return '';
  return Uri.parse(weebCentralBaseUrl).resolve(url).toString();
}

String normalizeLabel(String value) {
  return cleanText(value).toLowerCase().replaceAll(':', '');
}

bool looksLikeYes(String value) {
  final normalized = value.toLowerCase();
  return normalized == 'yes' || normalized == 'true' || normalized == 'si';
}

/// De un `srcset` (p. ej. "a.jpg 200w, b.jpg 800w"), regresa la URL
/// con el ancho declarado más grande. Si ninguna trae descriptor de
/// ancho, regresa la primera (mismo comportamiento de antes).
String? _widestSrcsetCandidate(String srcset) {
  String? best;
  var bestWidth = -1;

  for (final entry in srcset.split(',')) {
    final parts = entry.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) continue;

    var width = 0;
    if (parts.length > 1) {
      final match = RegExp(r'(\d+)w').firstMatch(parts[1]);
      if (match != null) {
        width = int.tryParse(match.group(1)!) ?? 0;
      }
    }

    if (width > bestWidth) {
      bestWidth = width;
      best = parts.first;
    }
  }

  return best;
}

String? firstCoverCandidate(Element root) {
  for (final image in root.querySelectorAll('img')) {
    final imgSrcset = image.attributes['srcset'] ?? '';
    if (imgSrcset.contains('temp.compsci88.com/cover') ||
        imgSrcset.contains('/cover/')) {
      final widest = _widestSrcsetCandidate(imgSrcset);
      if (widest != null && widest.isNotEmpty) {
        return absoluteWeebUrl(widest);
      }
    }

    final src = image.attributes['src'] ?? '';
    final dataSrc = image.attributes['data-src'] ?? '';
    final candidate = src.isNotEmpty ? src : dataSrc;

    if (candidate.contains('temp.compsci88.com/cover') ||
        candidate.contains('/cover/')) {
      return absoluteWeebUrl(candidate);
    }
  }

  for (final source in root.querySelectorAll('source')) {
    final srcSet = source.attributes['srcset'] ?? '';
    if (!srcSet.contains('temp.compsci88.com/cover') &&
        !srcSet.contains('/cover/')) {
      continue;
    }

    final widest = _widestSrcsetCandidate(srcSet);
    if (widest != null && widest.isNotEmpty) {
      return absoluteWeebUrl(widest);
    }
  }

  return null;
}

Element? labeledListItem(Element root, List<String> labels) {
  final targets = labels.map(normalizeLabel).toSet();

  for (final element in root.querySelectorAll('li')) {
    final strong = element.querySelector('strong');
    if (strong == null) continue;

    if (targets.contains(normalizeLabel(strong.text))) {
      return element;
    }
  }

  return null;
}

String valueByLabels(Element root, List<String> labels) {
  final item = labeledListItem(root, labels);
  if (item == null) return '';

  final strong = item.querySelector('strong');
  var text = cleanText(item.text);
  if (strong != null) {
    text = cleanText(text.replaceFirst(strong.text, ''));
  }

  return text.replaceFirst(RegExp(r'^:\s*'), '');
}

bool boolByLabels(Element root, List<String> labels) {
  return looksLikeYes(valueByLabels(root, labels));
}

List<String> linksByLabels(Element root, List<String> labels) {
  final item = labeledListItem(root, labels);
  if (item == null) return const [];

  final links = item
      .querySelectorAll('a')
      .map((link) => cleanText(link.text))
      .where((text) => text.isNotEmpty)
      .toList();

  if (links.isNotEmpty) return links;

  return item
      .querySelectorAll('span')
      .map((span) => cleanText(span.text))
      .where((text) => text.isNotEmpty)
      .toList();
}

String? seriesIdFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final index = uri.pathSegments.indexOf('series');
  if (index < 0 || index + 1 >= uri.pathSegments.length) {
    return null;
  }

  return uri.pathSegments[index + 1];
}

double chapterNumberFromTitle(String title) {
  final match = RegExp(
    r'(?:ch(?:apter)?[.\s-]*)(\d+(?:\.\d+)?)',
    caseSensitive: false,
  ).firstMatch(title);

  if (match != null) {
    return double.tryParse(match.group(1)!) ?? double.infinity;
  }

  final fallback = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(title);
  return fallback == null
      ? double.infinity
      : double.tryParse(fallback.group(1)!) ?? double.infinity;
}
