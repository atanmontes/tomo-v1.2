import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  }

  Future<int> pageFor(String mangaId, String chapterId) async {
    final prefs = await _preferences;
    return prefs.getInt('$_pagePrefix${mangaId}_$chapterId') ?? 0;
  }

  Future<void> setPage(String mangaId, String chapterId, int page) async {
    final prefs = await _preferences;
    await prefs.setInt('$_pagePrefix${mangaId}_$chapterId', page);
    await prefs.setString('$_lastPrefix$mangaId', chapterId);
  }

  bool hasUpdate(String id) => updatedIds.contains(id);

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

  Future<void> checkLibraryUpdates() async {
    if (checkingUpdates || items.isEmpty) return;
    checkingUpdates = true;
    notifyListeners();
    try {
      for (final manga in List<MangaItem>.from(items)) {
        try {
          final chapters = await _mangaService.fetchChapters(manga.id);
          await rememberChapterCount(manga.id, chapters.length);
        } catch (error) {
          debugPrint('TOMO update check failed for ${manga.id}: $error');
        }
      }
    } finally {
      checkingUpdates = false;
      notifyListeners();
    }
  }
}
