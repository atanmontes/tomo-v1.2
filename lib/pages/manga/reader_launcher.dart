import 'package:flutter/material.dart';

import '../../models/manga/manga.dart';
import '../../services/manga/manga_service.dart';
import '../../state/library_scope.dart';
import '../../theme/tomo_theme.dart';
import 'manga_detail_page.dart';
import 'manga_reader_page.dart';

Future<void> openMangaOrContinue(
  BuildContext context,
  MangaItem manga, {
  bool preferContinue = false,
}) async {
  if (!preferContinue) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MangaDetailPage(manga: manga)),
    );
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: tomoPink),
    ),
  );

  try {
    final store = LibraryScope.read(context);
    final service = MangaService();
    final chapters = await service.fetchChapters(manga.id);
    await store.rememberChapterCount(manga.id, chapters.length);

    final lastId = await store.lastChapterId(manga.id);
    final chapter = chapters.isEmpty
        ? null
        : chapters.firstWhere(
            (item) => item.id == lastId,
            orElse: () => chapters.first,
          );

    if (!context.mounted) return;
    Navigator.pop(context);

    if (chapter == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MangaDetailPage(manga: manga)),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaReaderPage(
          manga: manga,
          chapter: chapter,
          chapters: chapters,
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MangaDetailPage(manga: manga)),
    );
  }
}
