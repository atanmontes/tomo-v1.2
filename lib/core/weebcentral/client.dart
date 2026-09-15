import 'package:http/http.dart' as http;

import 'constants.dart';

class WeebCentralException implements Exception {
  final String message;
  final int? statusCode;
  final Uri? uri;

  const WeebCentralException(
    this.message, {
    this.statusCode,
    this.uri,
  });

  @override
  String toString() => message;
}

class WeebCentralClient {
  WeebCentralClient({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  Future<String> getHtml(
    Uri uri, {
    Duration timeout = const Duration(seconds: 15),
    int retries = 2,
  }) async {
    Object? lastError;

    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await _client
            .get(uri, headers: weebCentralHeaders)
            .timeout(timeout);

        if (response.statusCode == 200) {
          return response.body;
        }

        if (response.statusCode >= 500 && attempt < retries) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
          continue;
        }

        throw WeebCentralException(
          'WeebCentral returned HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
          uri: uri,
        );
      } on WeebCentralException {
        rethrow;
      } catch (error) {
        lastError = error;
        if (attempt >= retries) break;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }

    throw WeebCentralException(
      'Could not reach WeebCentral. ${lastError ?? ''}'.trim(),
      uri: uri,
    );
  }
}
