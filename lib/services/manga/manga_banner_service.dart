import 'dart:convert';

import 'package:http/http.dart' as http;

/// Trae un banner horizontal (formato ancho) desde AniList para
/// complementar el cover vertical de WeebCentral en el hero de
/// "Featured" de Home.
///
/// Es un servicio aparte y opcional: si AniList no encuentra el
/// título, la request falla, o se agota el tiempo, simplemente
/// regresa null y quien lo llame debe caer de vuelta al cover
/// normal. Nunca debe romper la carga de Home.
class MangaBannerService {
  MangaBannerService._();

  static final Map<String, String?> _cache = {};
  static final Map<String, Future<String?>> _inFlight = {};

  static const _endpoint = 'https://graphql.anilist.co';

  static const _query = r'''
    query ($search: String) {
      Media(search: $search, type: MANGA) {
        bannerImage
      }
    }
  ''';

  static Future<String?> fetchBanner(String title) {
    final key = title.trim().toLowerCase();

    if (key.isEmpty) return Future.value(null);

    if (_cache.containsKey(key)) {
      return Future.value(_cache[key]);
    }

    return _inFlight.putIfAbsent(
      key,
      () => _fetch(key, title),
    );
  }

  static Future<String?> _fetch(String key, String title) async {
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'query': _query,
              'variables': {'search': title},
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        _cache[key] = null;
        return null;
      }

      final decoded = jsonDecode(response.body);
      final banner =
          decoded['data']?['Media']?['bannerImage'];

      final result =
          banner is String && banner.isNotEmpty ? banner : null;

      _cache[key] = result;
      return result;
    } catch (_) {
      _cache[key] = null;
      return null;
    } finally {
      _inFlight.remove(key);
    }
  }
}
