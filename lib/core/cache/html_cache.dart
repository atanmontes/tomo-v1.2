import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HtmlCache {
  Directory? _dir;
  final Map<String, _Entry> _memory = {};

  Future<Directory> get _root async {
    if (_dir != null) return _dir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'tomo_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  String _key(String name) {
    return base64Url.encode(utf8.encode(name)).replaceAll('=', '');
  }

  Future<String?> read(String name, {required Duration ttl}) async {
    final memory = _memory[name];
    if (memory != null && DateTime.now().isBefore(memory.expires)) {
      return memory.body;
    }

    try {
      final file = File(p.join((await _root).path, _key(name)));
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final expires = DateTime.tryParse('${decoded['expires']}');
      final body = decoded['body'];
      if (expires == null || body is! String) return null;
      if (DateTime.now().isAfter(expires)) {
        await file.delete();
        return null;
      }
      _memory[name] = _Entry(body, expires);
      return body;
    } catch (error) {
      debugPrint('TOMO cache read failed: $error');
      return null;
    }
  }

  Future<void> write(
    String name,
    String body, {
    required Duration ttl,
  }) async {
    final expires = DateTime.now().add(ttl);
    _memory[name] = _Entry(body, expires);
    try {
      final file = File(p.join((await _root).path, _key(name)));
      await file.writeAsString(
        jsonEncode({
          'expires': expires.toIso8601String(),
          'body': body,
        }),
      );
    } catch (error) {
      debugPrint('TOMO cache write failed: $error');
    }
  }

  Future<void> clear() async {
    _memory.clear();
    try {
      final dir = await _root;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _dir = null;
    } catch (error) {
      debugPrint('TOMO cache clear failed: $error');
    }
  }
}

class _Entry {
  final String body;
  final DateTime expires;
  _Entry(this.body, this.expires);
}

final HtmlCache htmlCache = HtmlCache();
