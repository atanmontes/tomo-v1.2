import 'dart:async';

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
  Future<void> _tail = Future<void>.value();
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  static const Duration _minGap = Duration(milliseconds: 800);

  Future<T> _enqueue<T>(Future<T> Function() job) {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;

    return previous.then((_) async {
      try {
        final wait = _minGap - DateTime.now().difference(_lastRequest);
        if (wait > Duration.zero) {
          await Future<void>.delayed(wait);
        }
        return await job();
      } finally {
        _lastRequest = DateTime.now();
        if (!gate.isCompleted) gate.complete();
      }
    });
  }

  Future<String> getHtml(
    Uri uri, {
    Duration timeout = const Duration(seconds: 15),
    int retries = 3,
  }) {
    return _enqueue(() => _getHtml(uri, timeout: timeout, retries: retries));
  }

  Future<List<int>> getBytes(
    Uri uri, {
    Duration timeout = const Duration(seconds: 25),
    int retries = 3,
    Map<String, String>? headers,
  }) {
    return _enqueue(
      () => _getBytes(
        uri,
        timeout: timeout,
        retries: retries,
        headers: headers,
      ),
    );
  }

  Future<String> _getHtml(
    Uri uri, {
    required Duration timeout,
    required int retries,
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

        if (_shouldRetry(response.statusCode) && attempt < retries) {
          await Future<void>.delayed(_backoff(attempt, response));
          continue;
        }

        throw WeebCentralException(
          response.statusCode == 429
              ? 'WeebCentral está saturado (429). Espera un momento y reintenta.'
              : 'WeebCentral returned HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
          uri: uri,
        );
      } on WeebCentralException {
        rethrow;
      } catch (error) {
        lastError = error;
        if (attempt >= retries) break;
        await Future<void>.delayed(_backoff(attempt, null));
      }
    }

    throw WeebCentralException(
      'Could not reach WeebCentral. ${lastError ?? ''}'.trim(),
      uri: uri,
    );
  }

  Future<List<int>> _getBytes(
    Uri uri, {
    required Duration timeout,
    required int retries,
    Map<String, String>? headers,
  }) async {
    Object? lastError;

    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await _client
            .get(uri, headers: headers ?? weebCentralImageHeaders)
            .timeout(timeout);

        if (response.statusCode == 200) {
          return response.bodyBytes;
        }

        if (_shouldRetry(response.statusCode) && attempt < retries) {
          await Future<void>.delayed(_backoff(attempt, response));
          continue;
        }

        throw WeebCentralException(
          'Image download failed HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
          uri: uri,
        );
      } on WeebCentralException {
        rethrow;
      } catch (error) {
        lastError = error;
        if (attempt >= retries) break;
        await Future<void>.delayed(_backoff(attempt, null));
      }
    }

    throw WeebCentralException(
      'Could not download file. ${lastError ?? ''}'.trim(),
      uri: uri,
    );
  }

  bool _shouldRetry(int status) {
    return status == 429 || status == 503 || status >= 500;
  }

  Duration _backoff(int attempt, http.Response? response) {
    if (response != null && response.statusCode == 429) {
      final raw = response.headers['retry-after'];
      final seconds = int.tryParse(raw ?? '');
      if (seconds != null && seconds > 0) {
        return Duration(seconds: seconds.clamp(1, 20));
      }
      return Duration(seconds: (2 << attempt).clamp(2, 16));
    }
    return Duration(milliseconds: 500 * (attempt + 1));
  }
}

final WeebCentralClient weebCentralClient = WeebCentralClient();
