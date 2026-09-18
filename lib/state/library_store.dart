import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/manga/manga.dart';
import '../services/manga/manga_service.dart';

class LibraryStore extends ChangeNotifier {
  LibraryStore({MangaService? mangaService})
      : _mangaService = mangaService ?? MangaService();

  static const _libraryKey = 'tomo_library';
  static const _readPrefix = 'tomo_read_';
  static const _pagePrefix = 'tomo_page_';
  static const _lastPrefix = 'tomo_last_';
  static const _knownCountPrefix = 'tomo_known_count_';
  static const _openedPrefix = 'tomo_opened_';
  static const _offsetPrefix = 'tomo_offset_';
  static const _modePrefix = 'tomo_reader_mode_';

  final MangaService _mangaService;

  SharedPreferences? _prefs;
  List<MangaItem> items = [];
  final Map<String, int> readCounts = {};
  final Set<String> busyIds = <String>{};
  final Set<String> updatedIds = <String>{};
  bool loaded = false;
  bool checkingUpdates = false;

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  bool isInLibrary(String id) => items.any((item) => item.id == id);

  int readCountFor(String id) => readCounts[id] ?? 0;

  Future<void> load() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_libraryKey);

    if (raw == null || raw.isEmpty) {
      items = [];
      readCounts.clear();
      loaded = true;
      notifyListeners();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        loaded = true;
        notifyListeners();
        return;
      }

      final loadedItems = decoded
          .map(
            (item) => MangaItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      final counts = <String, int>{};
      for (final manga in loadedItems) {
        counts[manga.id] =
            prefs.getStringList('$_readPrefix${manga.id}')?.length ?? 0;
      }

      updatedIds
        ..clear()
        ..addAll(prefs.getStringList('tomo_updated_ids') ?? const []);

      items = loadedItems;
      readCounts
        ..clear()
        ..addAll(counts);
    } catch (error, stack) {
      debugPrint('TOMO library load failed: $error\n$stack');
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persistLibrary() async {
    final prefs = await _preferences;
    await prefs.setString(
      _libraryKey,
      jsonEncode(items.map((manga) => manga.toJson()).toList()),
    );
  }

  Future<void> toggle(MangaItem manga) async {
    if (busyIds.contains(manga.id)) return;

    busyIds.add(manga.id);
    notifyListeners();

    try {
      if (isInLibrary(manga.id)) {
        items.removeWhere((item) => item.id == manga.id);
        readCounts.remove(manga.id);
        updatedIds.remove(manga.id);
        await _persistLibrary();
        await _persistUpdatedIds();
      } else {
        final fullManga = manga.description.isEmpty || manga.cover.isEmpty
            ? await _mangaService.fetchManga(manga.url)
            : manga;
        items.insert(0, fullManga);
        readCounts[fullManga.id] = readCounts[fullManga.id] ?? 0;
        await _persistLibrary();
      }
    } catch (error, stack) {
      debugPrint('TOMO toggle library failed: $error\n$stack');
    } finally {
      busyIds.remove(manga.id);
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    if (busyIds.contains(id)) return;
    busyIds.add(id);
    notifyListeners();
    try {
      items.removeWhere((item) => item.id == id);
      readCounts.remove(id);
      updatedIds.remove(id);
      await _persistLibrary();
      await _persistUpdatedIds();
    } finally {
      busyIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> upsertDetails(MangaItem manga) async {
    final index = items.indexWhere((item) => item.id == manga.id);
    if (index < 0) return;
    items[index] = manga;
    await _persistLibrary();
    notifyListeners();
  }

  Future<Set<String>> readChapters(String mangaId) async {
    final prefs = await _preferences;
    return (prefs.getStringList('$_readPrefix$mangaId') ?? const <String>[])
        .toSet();
  }

  Future<void> setReadChapters(String mangaId, Set<String> chapterIds) async {
    final prefs = await _preferences;
    await prefs.setStringList('$_readPrefix$mangaId', chapterIds.toList());
    readCounts[mangaId] = chapterIds.length;
    notifyListeners();
  }

  Future<void> markChapterRead(String mangaId, String chapterId) async {
    final updated = await readChapters(mangaId);
    updated.add(chapterId);
    await setReadChapters(mangaId, updated);
  }

  Future<String?> lastChapterId(String mangaId) async {
    final prefs = await _preferences;
    return prefs.getString('$_lastPrefix$mangaId');
  }

  Future<void> setLastChapterId(String mangaId, String chapterId) async {
    final prefs = await _preferences;
    await prefs.setString('$_lastPrefix$mangaId', chapterId);
    await prefs.setInt('$_openedPrefix$mangaId', DateTime.now().millisecondsSinceEpoch);
  }

  Future<int> pageFor(String mangaId, String chapterId) async {
    final prefs = await _preferences;
    return prefs.getInt('$_pagePrefix${mangaId}_$chapterId') ?? 0;
  }

  Future<void> setPage(String mangaId, String chapterId, int page) async {
    final prefs = await _preferences;
    await prefs.setInt('$_pagePrefix${mangaId}_$chapterId', page);
    await prefs.setString('$_lastPrefix$mangaId', chapterId);
    await prefs.setInt('$_openedPrefix$mangaId', DateTime.now().millisecondsSinceEpoch);
  }

  /// Cuánto se ha scrolleado dentro de la imagen actual, medido en
  /// "pantallas" (unidades de viewport), no en píxeles.
  /// Solo la usa el modo webtoon; el modo paged siempre la deja en 0.
  Future<double> pageOffsetFor(String mangaId, String chapterId) async {
    final prefs = await _preferences;
    return prefs.getDouble('$_offsetPrefix${mangaId}_$chapterId') ?? 0;
  }

  Future<void> setPageOffset(
    String mangaId,
    String chapterId,
    double offset,
  ) async {
    final prefs = await _preferences;
    await prefs.setDouble(
      '$_offsetPrefix${mangaId}_$chapterId',
      offset < 0 ? 0 : offset,
    );
  }

  /// 'paged' | 'webtoon' — se recuerda por manga.
  Future<String> readerModeFor(String mangaId) async {
    final prefs = await _preferences;
    return prefs.getString('$_modePrefix$mangaId') ?? 'paged';
  }

  Future<void> setReaderMode(String mangaId, String mode) async {
    final prefs = await _preferences;
    await prefs.setString('$_modePrefix$mangaId', mode);
  }

  bool hasUpdate(String id) => updatedIds.contains(id);

  Future<int> openedAt(String mangaId) async {
    final prefs = await _preferences;
    return prefs.getInt('$_openedPrefix$mangaId') ?? 0;
  }

  List<MangaItem> continueReading({int limit = 8}) {
    final reading = items.where((manga) => readCountFor(manga.id) > 0).toList();
    return reading.take(limit).toList();
  }


  Future<void> rememberChapterCount(String mangaId, int count) async {
    final prefs = await _preferences;
    final known = prefs.getInt('$_knownCountPrefix$mangaId');
    await prefs.setInt('$_knownCountPrefix$mangaId', count);
    if (known != null && count > known) {
      updatedIds.add(mangaId);
    } else {
      updatedIds.remove(mangaId);
    }
    await _persistUpdatedIds();
    notifyListeners();
  }

  Future<void> clearUpdate(String mangaId) async {
    updatedIds.remove(mangaId);
    await _persistUpdatedIds();
    notifyListeners();
  }

  Future<void> _persistUpdatedIds() async {
    final prefs = await _preferences;
    await prefs.setStringList('tomo_updated_ids', updatedIds.toList());
  }

  bool pauseBackgroundUpdates = false;

  Future<void> checkLibraryUpdates({bool force = false}) async {
    if (checkingUpdates || items.isEmpty) return;
    checkingUpdates = true;
    notifyListeners();
    try {
      if (!force) {
        await Future<void>.delayed(const Duration(seconds: 4));
      }
      for (final manga in List<MangaItem>.from(items)) {
        while (pauseBackgroundUpdates) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        try {
          final chapters = await _mangaService.fetchChapters(manga.id);
          await rememberChapterCount(manga.id, chapters.length);
        } catch (error) {
          debugPrint('TOMO update check failed for ${manga.id}: $error');
        }
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    } finally {
      checkingUpdates = false;
      notifyListeners();
    }
  }

  Future<File> backupFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, 'tomo_backup.json'));
  }

  Future<File> exportBackup() async {
    final prefs = await _preferences;
    final progress = <String, dynamic>{};
    for (final manga in items) {
      final pages = <String, int>{};
      for (final key in prefs.getKeys()) {
        final prefix = '$_pagePrefix${manga.id}_';
        if (key.startsWith(prefix)) {
          pages[key.substring(prefix.length)] = prefs.getInt(key) ?? 0;
        }
      }
      progress[manga.id] = {
        'read': prefs.getStringList('$_readPrefix${manga.id}') ?? [],
        'last': prefs.getString('$_lastPrefix${manga.id}'),
        'knownCount': prefs.getInt('$_knownCountPrefix${manga.id}'),
        'pages': pages,
      };
    }

    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'library': items.map((manga) => manga.toJson()).toList(),
      'updated': updatedIds.toList(),
      'progress': progress,
    };

    final file = await backupFile();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }

  Future<int> importBackup(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Invalid backup file.');
    }

    final rawLibrary = decoded['library'];
    if (rawLibrary is! List) {
      throw const FormatException('Backup has no library.');
    }

    final loadedItems = rawLibrary
        .map((item) => MangaItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    items = loadedItems;
    await _persistLibrary();

    final prefs = await _preferences;
    final progress = decoded['progress'];
    if (progress is Map) {
      for (final entry in progress.entries) {
        final mangaId = '${entry.key}';
        final data = entry.value;
        if (data is! Map) continue;
        final read = data['read'];
        if (read is List) {
          await prefs.setStringList(
            '$_readPrefix$mangaId',
            read.map((item) => '$item').toList(),
          );
          readCounts[mangaId] = read.length;
        }
        final last = data['last'];
        if (last is String && last.isNotEmpty) {
          await prefs.setString('$_lastPrefix$mangaId', last);
        }
        final known = data['knownCount'];
        if (known is num) {
          await prefs.setInt('$_knownCountPrefix$mangaId', known.toInt());
        }
        final pages = data['pages'];
        if (pages is Map) {
          for (final page in pages.entries) {
            if (page.value is num) {
              await prefs.setInt(
                '$_pagePrefix${mangaId}_${page.key}',
                (page.value as num).toInt(),
              );
            }
          }
        }
      }
    }

    updatedIds
      ..clear()
      ..addAll(
        (decoded['updated'] is List)
            ? (decoded['updated'] as List).map((item) => '$item')
            : const [],
      );
    await _persistUpdatedIds();
    notifyListeners();
    return items.length;
  }
}
