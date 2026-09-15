import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/weebcentral/constants.dart';
import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/manga/manga_service.dart';
import '../../state/library_scope.dart';
import '../../theme/tomo_theme.dart';

enum ReaderMode { paged, webtoon }

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
  ReaderMode mode = ReaderMode.paged;
  bool _restoring = false;

  late ChapterItem activeChapter;
  PageController pageController = PageController();
  ScrollController webtoonController = ScrollController();

  Timer? _saveTimer;
  Timer? _hideTimer;
  bool progressLoading = true;

  @override
  void initState() {
    super.initState();
    activeChapter = widget.chapter;
    webtoonController.addListener(_onWebtoonScroll);
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
    webtoonController.removeListener(_onWebtoonScroll);
    pageController.dispose();
    webtoonController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  double _pageExtent(BuildContext context) {
    return MediaQuery.sizeOf(context).width * 1.4;
  }

  void _armHideTimer() {
    _hideTimer?.cancel();
    if (!uiVisible) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !uiVisible) return;
      setState(() => uiVisible = false);
    });
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
    final savedPage = await store.pageFor(widget.manga.id, activeChapter.id);
    if (!mounted) return;

    setState(() {
      currentPage = savedPage;
      progressLoading = false;
    });

    await store.setLastChapterId(widget.manga.id, activeChapter.id);
    await loadImages(initialPage: savedPage);
  }

  void _scheduleSaveProgress() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), _saveProgressNow);
  }

  Future<void> _saveProgressNow() async {
    _saveTimer?.cancel();
    if (images.isEmpty || !mounted) return;
    await LibraryScope.read(context).setPage(
      widget.manga.id,
      activeChapter.id,
      currentPage,
    );
  }

  Future<void> _markChapterAsRead(String chapterId) async {
    if (!mounted) return;
    await LibraryScope.read(context).markChapterRead(
      widget.manga.id,
      chapterId,
    );
  }

  Future<void> loadImages({int initialPage = 0}) async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final foundImages = await _mangaService.fetchChapterImages(
        activeChapter.id,
      );

      if (foundImages.isEmpty) {
        throw Exception('No pages found in this chapter.');
      }

      final safePage = initialPage.clamp(0, foundImages.length - 1);
      if (!mounted) return;

      setState(() {
        images = foundImages;
        currentPage = safePage;
        loading = false;
        error = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _restorePosition(safePage);
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

  void _restorePosition(int page) {
    _restoring = true;
    if (mode == ReaderMode.paged) {
      if (pageController.hasClients) {
        pageController.jumpToPage(page);
      }
    } else if (webtoonController.hasClients) {
      final offset = page * _pageExtent(context);
      final max = webtoonController.position.maxScrollExtent;
      webtoonController.jumpTo(offset.clamp(0, max));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoring = false;
    });
  }

  void _switchMode() {
    final page = currentPage;
    setState(() {
      mode = mode == ReaderMode.paged ? ReaderMode.webtoon : ReaderMode.paged;
      uiVisible = true;
    });
    _armHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restorePosition(page);
    });
  }

  void _onWebtoonScroll() {
    if (_restoring || mode != ReaderMode.webtoon || images.isEmpty) return;
    if (!webtoonController.hasClients) return;

    final extent = _pageExtent(context);
    if (extent <= 0) return;

    final page = (webtoonController.offset / extent)
        .floor()
        .clamp(0, images.length - 1);

    if (page == currentPage) return;

    currentPage = page;
    _scheduleSaveProgress();
    _precacheNearbyPages(page);

    if (page >= images.length - 1) {
      _markChapterAsRead(activeChapter.id);
    }
  }

  void _precacheNearbyPages(int page) {
    if (!mounted || images.isEmpty) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (screenWidth * pixelRatio * 1.25).round();
    final candidates = <int>{page + 1, page + 2, if (page > 0) page - 1};

    for (final index in candidates) {
      if (index < 0 || index >= images.length) continue;
      precacheImage(
        ResizeImage(
          NetworkImage(images[index], headers: weebCentralImageHeaders),
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
    if (index < 0 || index >= widget.chapters.length - 1) return null;
    return widget.chapters[index + 1];
  }

  Future<void> _openChapter(ChapterItem chapter) async {
    if (chapter.id == activeChapter.id) return;
    await _saveProgressNow();
    if (!mounted) return;

    final savedPage = await LibraryScope.read(context).pageFor(
      widget.manga.id,
      chapter.id,
    );

    setState(() {
      activeChapter = chapter;
      currentPage = savedPage;
      images = [];
      loading = true;
      error = null;
    });

    await LibraryScope.read(context).setLastChapterId(
      widget.manga.id,
      chapter.id,
    );
    await loadImages(initialPage: savedPage);
  }

  Future<void> _goToPreviousPage() async {
    if (mode != ReaderMode.paged || currentPage <= 0) return;
    if (!pageController.hasClients) return;
    pageController.previousPage(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToNextPage() async {
    if (mode != ReaderMode.paged || currentPage >= images.length - 1) return;
    if (!pageController.hasClients) return;
    pageController.nextPage(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToNextChapter() async {
    final chapter = _nextChapter;
    if (chapter == null) return;
    await _markChapterAsRead(activeChapter.id);
    await _openChapter(chapter);
  }

  void _onPagedTap(Offset local, Size size) {
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
              backgroundColor: Colors.black.withOpacity(0.72),
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  tooltip: mode == ReaderMode.paged
                      ? 'Webtoon mode'
                      : 'Page mode',
                  onPressed: _switchMode,
                  icon: Icon(
                    mode == ReaderMode.paged
                        ? Icons.view_day_outlined
                        : Icons.auto_stories_outlined,
                  ),
                ),
              ],
            )
          : null,
      body: progressLoading || loading
          ? const Center(
              child: CircularProgressIndicator(color: tomoPink),
            )
          : error != null
              ? _ReaderError(
                  message: error!,
                  onRetry: () => loadImages(initialPage: currentPage),
                )
              : images.isEmpty
                  ? const Center(
                      child: Text(
                        'No pages found.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Stack(
                      children: [
                        mode == ReaderMode.paged
                            ? _buildPageMode()
                            : _buildWebtoonMode(),
                        if (uiVisible && mode == ReaderMode.paged)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 24,
                            child: _PagedFooter(
                              pageText:
                                  'Page ${currentPage + 1} of ${images.length}',
                              showNext: currentPage == images.length - 1 &&
                                  _nextChapter != null,
                              onNext: _goToNextChapter,
                            ),
                          ),
                      ],
                    ),
    );
  }

  Widget _buildPageMode() {
    return PageView.builder(
      controller: pageController,
      itemCount: images.length,
      allowImplicitScrolling: true,
      onPageChanged: (index) {
        if (currentPage == index) return;
        setState(() => currentPage = index);
        _scheduleSaveProgress();
        _precacheNearbyPages(index);
        if (index == images.length - 1) {
          _markChapterAsRead(activeChapter.id);
        }
      },
      itemBuilder: (context, index) {
        final cacheWidth =
            (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context) *
                    1.25)
                .round();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            _onPagedTap(details.localPosition, MediaQuery.sizeOf(context));
          },
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                images[index],
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                headers: weebCentralImageHeaders,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: tomoPink),
                  );
                },
                errorBuilder: (_, __, ___) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white24,
                      size: 50,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebtoonMode() {
    final next = _nextChapter;
    final minHeight = _pageExtent(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleUi,
      child: ListView.builder(
        controller: webtoonController,
        cacheExtent: minHeight * 4,
        itemCount: images.length + 1,
        itemBuilder: (context, index) {
          if (index == images.length) {
            return _WebtoonChapterFooter(
              hasNext: next != null,
              nextTitle: next?.title,
              onNext: next == null ? null : _goToNextChapter,
            );
          }

          return _WebtoonImage(
            url: images[index],
            minHeight: minHeight,
          );
        },
      ),
    );
  }
}

class _WebtoonImage extends StatelessWidget {
  final String url;
  final double minHeight;

  const _WebtoonImage({
    required this.url,
    required this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Image.network(
        url,
        fit: BoxFit.fitWidth,
        width: double.infinity,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        headers: weebCentralImageHeaders,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: minHeight,
            child: const Center(
              child: CircularProgressIndicator(color: tomoPink),
            ),
          );
        },
        errorBuilder: (_, __, ___) {
          return SizedBox(
            height: minHeight,
            child: const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white24,
                size: 42,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WebtoonChapterFooter extends StatelessWidget {
  final bool hasNext;
  final String? nextTitle;
  final VoidCallback? onNext;

  const _WebtoonChapterFooter({
    required this.hasNext,
    required this.nextTitle,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
      child: Column(
        children: [
          const Text(
            'End of chapter',
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (hasNext)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: onNext,
                style: FilledButton.styleFrom(backgroundColor: tomoPink),
                icon: const Icon(Icons.skip_next_rounded),
                label: Text(
                  nextTitle == null || nextTitle!.isEmpty
                      ? 'Next chapter'
                      : 'Next — $nextTitle',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            const Text(
              'No more chapters.',
              style: TextStyle(color: Colors.white38),
            ),
        ],
      ),
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Material(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Next',
              style: TextStyle(fontWeight: FontWeight.w800),
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
            const Icon(Icons.error_outline, size: 50, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'Could not load chapter.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: tomoPink),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
