import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/weebcentral/constants.dart';
import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/download/download_service.dart';
import '../../services/manga/manga_service.dart';
import '../../state/library_scope.dart';
import '../../theme/tomo_theme.dart';

class MangaReaderPage extends StatefulWidget {
  final MangaItem manga;
  final ChapterItem chapter;
  final List<ChapterItem> chapters;

  const MangaReaderPage({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapters,
  });

  @override
  State<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends State<MangaReaderPage> {
  final MangaService _mangaService = MangaService();

  List<String> images = [];
  bool loading = true;
  String? error;
  int currentPage = 0;
  bool uiVisible = true;

  late ChapterItem activeChapter;
  late final PageController pageController;

  // --- Webtoon / stripe ---
  late final ItemScrollController itemScrollController;
  late final ItemPositionsListener itemPositionsListener;

  /// 'paged' | 'webtoon'
  String readerMode = 'paged';

  /// Scroll dentro de la imagen actual, en unidades de viewport.
  double currentOffset = 0;

  /// Bloquea el guardado mientras restauramos la posición,
  /// para que el listener no sobrescriba el progreso con 0.
  bool _restoringWebtoon = false;

  /// Evita marcar el capítulo como leído en cada tick del scroll.
  bool _endMarked = false;

  /// True cuando el último ítem ya se vio completo. Independiente
  /// de currentPage (que a propósito sigue al ítem de ARRIBA, para
  /// reanudar bien), así el botón "Next" no se queda atorado
  /// mientras la penúltima imagen todavía asoma en pantalla.
  bool atChapterEnd = false;

  Timer? _saveTimer;
  Timer? _hideTimer;
  bool progressLoading = true;

  @override
  void initState() {
    super.initState();

    activeChapter = widget.chapter;
    pageController = PageController();

    itemScrollController = ItemScrollController();
    itemPositionsListener = ItemPositionsListener.create();
    itemPositionsListener.itemPositions.addListener(
      _onWebtoonPositionsChanged,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadProgressAndChapter();
    });

    _armHideTimer();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _hideTimer?.cancel();
    itemPositionsListener.itemPositions.removeListener(
      _onWebtoonPositionsChanged,
    );
    pageController.dispose();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    super.dispose();
  }

  void _armHideTimer() {
    _hideTimer?.cancel();

    if (!uiVisible) return;

    _hideTimer = Timer(
      const Duration(seconds: 3),
      () {
        if (!mounted || !uiVisible) return;

        setState(() => uiVisible = false);
      },
    );
  }

  void _toggleUi() {
    setState(() => uiVisible = !uiVisible);

    if (uiVisible) {
      _armHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  Future<void> _loadProgressAndChapter() async {
    final store = LibraryScope.read(context);

    final mode = await store.readerModeFor(widget.manga.id);

    final savedPage = await store.pageFor(
      widget.manga.id,
      activeChapter.id,
    );

    final savedOffset = await store.pageOffsetFor(
      widget.manga.id,
      activeChapter.id,
    );

    if (!mounted) return;

    setState(() {
      readerMode = mode;
      currentPage = savedPage;
      currentOffset = mode == 'webtoon' ? savedOffset : 0;
      _restoringWebtoon = mode == 'webtoon';
      _endMarked = false;
      atChapterEnd = false;
      progressLoading = false;
    });

    await store.setLastChapterId(
      widget.manga.id,
      activeChapter.id,
    );

    await loadImages(initialPage: savedPage);
  }

  void _scheduleSaveProgress() {
    _saveTimer?.cancel();

    _saveTimer = Timer(
      const Duration(milliseconds: 250),
      _saveProgressNow,
    );
  }

  Future<void> _saveProgressNow() async {
    _saveTimer?.cancel();

    if (images.isEmpty || !mounted) return;

    // En webtoon nunca guardamos mientras restauramos o si la lista
    // todavía no reporta posiciones: ahí currentPage vale 0 y
    // borraría el progreso bueno.
    if (readerMode == 'webtoon' &&
        (_restoringWebtoon ||
            itemPositionsListener.itemPositions.value.isEmpty)) {
      return;
    }

    final store = LibraryScope.read(context);

    await store.setPage(
      widget.manga.id,
      activeChapter.id,
      currentPage,
    );

    await store.setPageOffset(
      widget.manga.id,
      activeChapter.id,
      readerMode == 'webtoon' ? currentOffset : 0,
    );
  }

  /// Traduce la posición del scroll a (índice de imagen + offset).
  /// Nunca guardamos píxeles: al restaurar las imágenes aún no
  /// midieron y el offset caería en otro lado.
  void _onWebtoonPositionsChanged() {
    if (!mounted ||
        readerMode != 'webtoon' ||
        images.isEmpty ||
        _restoringWebtoon) {
      return;
    }

    final positions =
        itemPositionsListener.itemPositions.value;

    if (positions.isEmpty) return;

    final visible = positions
        .where((position) => position.itemTrailingEdge > 0)
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (visible.isEmpty) return;

    final first = visible.first;
    final last = visible.last;

    // itemLeadingEdge viene en unidades de viewport y es justo lo
    // que ItemScrollController.jumpTo espera como alignment.
    final offset =
        first.itemLeadingEdge < 0 ? -first.itemLeadingEdge : 0.0;

    final reachedEnd = last.index == images.length - 1 &&
        last.itemTrailingEdge <= 1.02;

    final indexChanged = first.index != currentPage;
    final offsetChanged =
        (offset - currentOffset).abs() > 0.01;
    final endChanged = reachedEnd != atChapterEnd;

    if (indexChanged || offsetChanged || endChanged) {
      setState(() {
        currentPage = first.index;
        currentOffset = offset;
        atChapterEnd = reachedEnd;

        if (reachedEnd) uiVisible = true;
      });

      if (indexChanged || offsetChanged) {
        _scheduleSaveProgress();
      }

      if (indexChanged) {
        _precacheNearbyPages(first.index);
      }
    }

    if (reachedEnd && !_endMarked) {
      _endMarked = true;
      _hideTimer?.cancel();
      _markChapterAsRead(activeChapter.id);
    }
  }

  Future<void> _toggleReaderMode() async {
    final next =
        readerMode == 'webtoon' ? 'paged' : 'webtoon';

    await _saveProgressNow();

    if (!mounted) return;

    // Los dos modos comparten el índice de imagen, así que
    // cambiar de vista no pierde el lugar.
    setState(() {
      readerMode = next;
      currentOffset = 0;
      _restoringWebtoon = next == 'webtoon';
    });

    await LibraryScope.read(context).setReaderMode(
      widget.manga.id,
      next,
    );

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (next == 'webtoon') {
        if (itemScrollController.isAttached) {
          itemScrollController.jumpTo(
            index: currentPage,
            alignment: 0,
          );
        }

        _restoringWebtoon = false;
      } else if (pageController.hasClients) {
        pageController.jumpToPage(currentPage);
      }
    });
  }

  Future<void> _markChapterAsRead(String chapterId) async {
    if (!mounted) return;

    await LibraryScope.read(context).markChapterRead(
      widget.manga.id,
      chapterId,
    );
  }

  Future<void> loadImages({
    int initialPage = 0,
  }) async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      var foundImages =
          await downloadService.localPages(
        widget.manga.id,
        activeChapter.id,
      );

      if (foundImages.isEmpty) {
        foundImages =
            await _mangaService.fetchChapterImages(
          activeChapter.id,
        );
      }

      if (foundImages.isEmpty) {
        throw Exception(
          'No pages found in this chapter.',
        );
      }

      final safePage = initialPage.clamp(
        0,
        foundImages.length - 1,
      );

      if (!mounted) return;

      setState(() {
        images = foundImages;
        currentPage = safePage;
        loading = false;
        error = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (readerMode == 'webtoon') {
          // Anclamos al ítem, no al pixel: funciona aunque las
          // imágenes todavía no hayan cargado.
          if (itemScrollController.isAttached) {
            itemScrollController.jumpTo(
              index: safePage,
              alignment: -currentOffset,
            );
          }

          _restoringWebtoon = false;
        } else {
          if (!pageController.hasClients) return;

          pageController.jumpToPage(safePage);
        }

        _precacheNearbyPages(safePage);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  void _precacheNearbyPages(int page) {
    if (!mounted || images.isEmpty) return;

    final screenWidth =
        MediaQuery.sizeOf(context).width;

    final pixelRatio =
        MediaQuery.devicePixelRatioOf(context);

    final cacheWidth =
        (screenWidth * pixelRatio * 1.25).round();

    final candidates = <int>{
      page + 1,
      page + 2,
      if (page > 0) page - 1,
    };

    for (final index in candidates) {
      if (index < 0 || index >= images.length) {
        continue;
      }

      final source = images[index];

      if (source.startsWith('/') ||
          source.startsWith('file:')) {
        continue;
      }

      precacheImage(
        ResizeImage(
          NetworkImage(
            source,
            headers: weebCentralImageHeaders,
          ),
          width: cacheWidth,
        ),
        context,
      );
    }
  }

  int get _activeChapterIndex {
    return widget.chapters.indexWhere(
      (chapter) => chapter.id == activeChapter.id,
    );
  }

  ChapterItem? get _nextChapter {
    final index = _activeChapterIndex;

    if (index < 0 ||
        index >= widget.chapters.length - 1) {
      return null;
    }

    return widget.chapters[index + 1];
  }

  Future<void> _openChapter(
    ChapterItem chapter,
  ) async {
    if (chapter.id == activeChapter.id) return;

    await _saveProgressNow();

    if (!mounted) return;

    final savedPage =
        await LibraryScope.read(context).pageFor(
      widget.manga.id,
      chapter.id,
    );

    final savedOffset =
        await LibraryScope.read(context).pageOffsetFor(
      widget.manga.id,
      chapter.id,
    );

    setState(() {
      activeChapter = chapter;
      currentPage = savedPage;
      currentOffset =
          readerMode == 'webtoon' ? savedOffset : 0;
      _restoringWebtoon = readerMode == 'webtoon';
      _endMarked = false;
      atChapterEnd = false;
      images = [];
      loading = true;
      error = null;
    });

    await LibraryScope.read(context).setLastChapterId(
      widget.manga.id,
      chapter.id,
    );

    await loadImages(
      initialPage: savedPage,
    );
  }

  Future<void> _goToPreviousPage() async {
    if (currentPage <= 0 ||
        !pageController.hasClients) {
      return;
    }

    pageController.previousPage(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToNextPage() async {
    if (currentPage >= images.length - 1 ||
        !pageController.hasClients) {
      return;
    }

    pageController.nextPage(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToNextChapter() async {
    final chapter = _nextChapter;

    if (chapter == null) return;

    await _markChapterAsRead(
      activeChapter.id,
    );

    await _openChapter(chapter);
  }

  void _onPagedTap(
    Offset local,
    Size size,
  ) {
    final x = local.dx / size.width;

    if (x < 0.28) {
      _goToPreviousPage();
    } else if (x > 0.72) {
      _goToNextPage();
    } else {
      _toggleUi();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: uiVisible
          ? AppBar(
              backgroundColor:
                  Colors.black.withOpacity(0.72),
              elevation: 0,
              titleSpacing: 4,
              leading: IconButton(
                onPressed: () {
                  _saveProgressNow();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
              ),
              title: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.manga.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    activeChapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: _toggleReaderMode,
                  tooltip: readerMode == 'webtoon'
                      ? 'Paged view'
                      : 'Webtoon view',
                  icon: Icon(
                    readerMode == 'webtoon'
                        ? Icons.auto_stories_outlined
                        : Icons.view_day_outlined,
                  ),
                ),
              ],
            )
          : null,
      body: progressLoading || loading
          ? const Center(
              child: CircularProgressIndicator(
                color: tomoPink,
              ),
            )
          : error != null
              ? _ReaderError(
                  message: error!,
                  onRetry: () => loadImages(
                    initialPage: currentPage,
                  ),
                )
              : images.isEmpty
                  ? const Center(
                      child: Text(
                        'No pages found.',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    )
                  : readerMode == 'webtoon'
                      ? Stack(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior
                                  .translucent,
                              onTap: _toggleUi,
                              child:
                                  ScrollablePositionedList
                                      .builder(
                                itemCount: images.length,
                                itemScrollController:
                                    itemScrollController,
                                itemPositionsListener:
                                    itemPositionsListener,
                                itemBuilder: (
                                  context,
                                  index,
                                ) {
                                  final cacheWidth =
                                      (MediaQuery.sizeOf(
                                                    context,
                                                  ).width *
                                              MediaQuery
                                                  .devicePixelRatioOf(
                                                context,
                                              ) *
                                              1.25)
                                          .round();

                                  return _ReaderImage(
                                    source: images[index],
                                    cacheWidth: cacheWidth,
                                    webtoon: true,
                                  );
                                },
                              ),
                            ),
                            if (uiVisible)
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 24,
                                child: _PagedFooter(
                                  pageText:
                                      'Page ${currentPage + 1} of ${images.length}',
                                  showNext: atChapterEnd &&
                                      _nextChapter != null,
                                  onNext: _goToNextChapter,
                                ),
                              ),
                          ],
                        )
                      : Stack(
                      children: [
                        PageView.builder(
                          controller: pageController,
                          itemCount: images.length,
                          allowImplicitScrolling: true,
                          onPageChanged: (index) {
                            if (currentPage == index) {
                              return;
                            }

                            final reachedEnd =
                                index == images.length - 1;

                            setState(() {
                              currentPage = index;
                              currentOffset = 0;

                              if (reachedEnd) {
                                uiVisible = true;
                              }
                            });

                            _scheduleSaveProgress();
                            _precacheNearbyPages(index);

                            if (reachedEnd) {
                              _hideTimer?.cancel();

                              _markChapterAsRead(
                                activeChapter.id,
                              );
                            }
                          },
                          itemBuilder: (
                            context,
                            index,
                          ) {
                            final cacheWidth =
                                (MediaQuery.sizeOf(context)
                                            .width *
                                        MediaQuery
                                            .devicePixelRatioOf(
                                          context,
                                        ) *
                                        1.25)
                                    .round();

                            return GestureDetector(
                              behavior:
                                  HitTestBehavior.opaque,
                              onTapUp: (details) {
                                _onPagedTap(
                                  details.localPosition,
                                  MediaQuery.sizeOf(
                                    context,
                                  ),
                                );
                              },
                              child: InteractiveViewer(
                                minScale: 1,
                                maxScale: 4,
                                child: Center(
                                  child: _ReaderImage(
                                    source: images[index],
                                    cacheWidth: cacheWidth,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (uiVisible)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 24,
                            child: _PagedFooter(
                              pageText:
                                  'Page ${currentPage + 1} of ${images.length}',
                              showNext:
                                  currentPage ==
                                          images.length - 1 &&
                                      _nextChapter != null,
                              onNext: _goToNextChapter,
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class _ReaderImage extends StatelessWidget {
  final String source;
  final int cacheWidth;
  final bool webtoon;

  const _ReaderImage({
    required this.source,
    required this.cacheWidth,
    this.webtoon = false,
  });

  bool get _isFile {
    return source.startsWith('/') ||
        source.startsWith('file:');
  }

  @override
  Widget build(BuildContext context) {
    final error = const Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.white24,
        size: 50,
      ),
    );

    // En webtoon el placeholder necesita altura propia: si el ítem
    // mide 0 mientras carga, el índice visible se vuelve basura.
    final loading = webtoon
        ? const SizedBox(
            height: 420,
            child: Center(
              child: CircularProgressIndicator(
                color: tomoPink,
              ),
            ),
          )
        : const Center(
            child: CircularProgressIndicator(
              color: tomoPink,
            ),
          );

    final fit = webtoon
        ? BoxFit.fitWidth
        : BoxFit.contain;

    final height = webtoon ? null : double.infinity;

    if (_isFile) {
      final path = source.startsWith('file:')
          ? Uri.parse(source).toFilePath()
          : source;

      return Image.file(
        File(path),
        fit: fit,
        width: double.infinity,
        height: height,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => error,
      );
    }

    return Image.network(
      source,
      fit: fit,
      width: double.infinity,
      height: height,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      headers: weebCentralImageHeaders,
      frameBuilder: (
        context,
        child,
        frame,
        wasSynchronouslyLoaded,
      ) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }

        return loading;
      },
      errorBuilder: (_, __, ___) => error,
    );
  }
}

class _PagedFooter extends StatelessWidget {
  final String pageText;
  final bool showNext;
  final VoidCallback onNext;

  const _PagedFooter({
    required this.pageText,
    required this.showNext,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Material(
          color: Colors.black.withOpacity(0.55),
          borderRadius:
              BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: Text(
              pageText,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: tomoPink,
              ),
            ),
          ),
        ),
        const Spacer(),
        if (showNext)
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              backgroundColor: tomoPink,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Next',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReaderError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReaderError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load chapter.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: tomoPink,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}