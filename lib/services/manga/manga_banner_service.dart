import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resultado de buscar un manga en AniList: puede traer un banner
/// horizontal (bannerImage) y/o un cover en alta resolución
/// (coverImage.extraLarge), que es bastante mejor que el thumbnail
/// que da WeebCentral.
class MangaBannerResult {
  final String? bannerImage;
  final String? coverImage;

  const MangaBannerResult({this.bannerImage, this.coverImage});

  bool get isEmpty => bannerImage == null && coverImage == null;
}

/// Trae imágenes desde AniList para complementar el cover vertical
/// de WeebCentral en el hero de "Featured" de Home.
///
/// Es un servicio aparte y opcional: si AniList no encuentra nada,
/// la request falla, o se agota el tiempo, regresa un resultado
/// vacío en silencio y quien lo llame debe caer de vuelta al cover
/// normal. Nunca debe romper la carga de Home.
class MangaBannerService {
  MangaBannerService._();

  static const _empty = MangaBannerResult();

  static final Map<String, MangaBannerResult> _cache = {};
  static final Map<String, Future<MangaBannerResult>> _inFlight = {};

  static const _endpoint = 'https://graphql.anilist.co';

  static const _query = r'''
    query ($search: String) {
      Media(search: $search, type: MANGA) {
        bannerImage
        coverImage {
          extraLarge
        }
      }
    }
  ''';

  /// [altTitles] son títulos alternos (p. ej. associatedNames del
  /// manga) que se intentan, en orden, si [title] no da resultado.
  static Future<MangaBannerResult> fetchImages(
    String title, {
    List<String> altTitles = const [],
  }) {
    final key = title.trim().toLowerCase();

    if (key.isEmpty) return Future.value(_empty);

    if (_cache.containsKey(key)) {
      return Future.value(_cache[key]);
    }

    final candidates = [
      title,
      ...altTitles.where((alt) => alt.trim().isNotEmpty),
    ];

    return _inFlight.putIfAbsent(
      key,
      () => _fetchFirstMatch(key, candidates),
    );
  }

  static Future<MangaBannerResult> _fetchFirstMatch(
    String key,
    List<String> candidates,
  ) async {
    try {
      // Máximo 2 intentos (título principal + un alterno) para no
      // disparar de más peticiones por cada manga featured.
      for (final candidate in candidates.take(2)) {
        final result = await _fetchOne(candidate);

        if (!result.isEmpty) {
          _cache[key] = result;
          return result;
        }
      }

      _cache[key] = _empty;
      return _empty;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<MangaBannerResult> _fetchOne(String title) async {
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

      if (response.statusCode != 200) return _empty;

      final decoded = jsonDecode(response.body);
      final media = decoded['data']?['Media'];

      if (media == null) return _empty;

      final banner = media['bannerImage'];
      final cover = media['coverImage']?['extraLarge'];

      return MangaBannerResult(
        bannerImage: banner is String && banner.isNotEmpty ? banner : null,
        coverImage: cover is String && cover.isNotEmpty ? cover : null,
      );
    } catch (_) {
      return _empty;
    }
  }
}
