import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/weebcentral/client.dart';
import '../../core/weebcentral/constants.dart';
import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../manga/manga_service.dart';

class DownloadService {
  DownloadService({
    MangaService? mangaService,
    WeebCentralClient? client,
  })  : _mangaService = mangaService ?? MangaService(),
        _client = client ?? weebCentralClient;

  final MangaService _mangaService;
  final WeebCentralClient _client;
  final Set<String> busy = <String>{};

  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'tomo_downloads'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _chapterDir(String mangaId, String chapterId) async {
    final dir = Directory(p.join((await _root()).path, mangaId, chapterId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String key(String mangaId, String chapterId) => '$mangaId::$chapterId';

  Future<bool> isDownloaded(String mangaId, String chapterId) async {
    final pages = await localPages(mangaId, chapterId);
    return pages.isNotEmpty;
  }

  Future<List<String>> localPages(String mangaId, String chapterId) async {
    try {
      final dir = Directory(
        p.join((await _root()).path, mangaId, chapterId),
      );
      if (!await dir.exists()) return const [];
      final manifest = File(p.join(dir.path, 'pages.json'));
      if (await manifest.exists()) {
        final decoded = jsonDecode(await manifest.readAsString());
        if (decoded is List) {
          final files = decoded
              .map((item) => p.join(dir.path, '$item'))
              .where((path) => File(path).existsSync())
              .toList();
          if (files.isNotEmpty) return files;
        }
      }
      final files = dir
          .listSync()
          .whereType<File>()
          .where((file) => !file.path.endsWith('pages.json'))
          .map((file) => file.path)
          .toList()
        ..sort();
      return files;
    } catch (error) {
      debugPrint('TOMO local pages failed: $error');
      return const [];
    }
  }

  Future<void> downloadChapter({
    required MangaItem manga,
    required ChapterItem chapter,
    void Function(int done, int total)? onProgress,
  }) async {
    final id = key(manga.id, chapter.id);
    if (busy.contains(id)) return;
    busy.add(id);
    try {
      final pages = await _mangaService.fetchChapterImages(chapter.id);
      if (pages.isEmpty) {
        throw const WeebCentralException('No pages to download.');
      }
      final dir = await _chapterDir(manga.id, chapter.id);
      final names = <String>[];
      for (var i = 0; i < pages.length; i++) {
        final name = '${(i + 1).toString().padLeft(3, '0')}.img';
        final file = File(p.join(dir.path, name));
        final bytes = await _client.getBytes(
          Uri.parse(pages[i]),
          headers: weebCentralImageHeaders,
        );
        await file.writeAsBytes(bytes, flush: true);
        names.add(name);
        onProgress?.call(i + 1, pages.length);
      }
      await File(p.join(dir.path, 'pages.json')).writeAsString(
        jsonEncode(names),
      );
      await File(p.join(dir.path, 'meta.json')).writeAsString(
        jsonEncode({
          'mangaId': manga.id,
          'mangaTitle': manga.title,
          'chapterId': chapter.id,
          'chapterTitle': chapter.title,
        }),
      );
    } finally {
      busy.remove(id);
    }
  }

  Future<void> deleteChapter(String mangaId, String chapterId) async {
    final dir = Directory(p.join((await _root()).path, mangaId, chapterId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> clearAll() async {
    final dir = await _root();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

final DownloadService downloadService = DownloadService();
