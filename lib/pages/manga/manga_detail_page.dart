import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/manga/manga_service.dart';
import '../../theme/tomo_theme.dart';
import '../../widgets/manga/tomo_network_image.dart';
import '../../state/library_scope.dart';
import 'manga_reader_page.dart';

class MangaDetailPage extends StatefulWidget {
  final MangaItem manga;

  const MangaDetailPage({
    super.key,
    required this.manga,
  });

  @override
  State<MangaDetailPage> createState() =>
      _MangaDetailPageState();
}

class _MangaDetailPageState
    extends State<MangaDetailPage> {
  final MangaService _mangaService = MangaService();
  List<ChapterItem> chapters = [];

  MangaItem? _detailsManga;

  bool loadingChapters = true;
  String? chapterError;

  String? lastChapterId;
  Set<String> readChapters = <String>{};

  final TextEditingController _chapterSearchController =
      TextEditingController();

  String _chapterSearch = '';

  bool _synopsisExpanded = false;
  bool _detailsExpanded = false;

  @override
  void dispose() {
    _chapterSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDetails();
    loadChapters();
    _loadProgress();
  }

  Future<void> _loadDetails() async {
    try {
      final found = await _mangaService.fetchManga(
        widget.manga.url,
      );

      if (!mounted) return;

      setState(() {
        _detailsManga = found;
      });
      await LibraryScope.read(context).upsertDetails(found);
    } catch (_) {
      // The detail page can continue using the manga
      // received from search/library if the metadata request fails.
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();

    final last = prefs.getString(
      'tomo_last_${widget.manga.id}',
    );

    final read = prefs.getStringList(
          'tomo_read_${widget.manga.id}',
        ) ??
        <String>[];

    if (!mounted) return;

    setState(() {
      lastChapterId = last;
      readChapters = read.toSet();
    });
  }

  Future<void> _toggleChapterRead(
    String chapterId,
  ) async {
    final updated = <String>{...readChapters};

    if (updated.contains(chapterId)) {
      updated.remove(chapterId);
    } else {
      updated.add(chapterId);
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'tomo_read_${widget.manga.id}',
      updated.toList(),
    );

    if (!mounted) return;

    setState(() {
      readChapters = updated;
    });
  }

  Future<void> loadChapters() async {
    setState(() {
      loadingChapters = true;
      chapterError = null;
    });

    try {
      final found = await _mangaService.fetchChapters(
        widget.manga.id,
      );

      if (!mounted) return;

      setState(() {
        chapters = found;
        loadingChapters = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingChapters = false;
        chapterError = e.toString();
      });
    }
  }

  List<ChapterItem> get _filteredChapters {
    final query =
        _chapterSearch.trim().toLowerCase();

    if (query.isEmpty) return chapters;

    return chapters.where((chapter) {
      return chapter.title
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
  final manga = _detailsManga ?? widget.manga;

    final readCount = chapters
        .where(
          (c) => readChapters.contains(c.id),
        )
        .length;

    final totalCount = chapters.length;

    return Scaffold(
      backgroundColor: tomoBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: tomoPink,
          backgroundColor: tomoCard,
          onRefresh: loadChapters,
          child: CustomScrollView(
            cacheExtent: 500,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: manga.cover.isEmpty
                            ? Container(
                                width: 260,
                                height: 380,
                                color: tomoCard,
                                child: const Icon(
                                  Icons.menu_book,
                                  size: 60,
                                  color: Colors.white24,
                                ),
                              )
                            : TomoNetworkImage(
                                url: manga.cover,
                                width: 260,
                                height: 380,
                                fit: BoxFit.cover,
                                cacheWidth: (260 *
                                        MediaQuery.devicePixelRatioOf(context) *
                                        1.15)
                                    .round(),
                              ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        manga.title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ========================================================
                      // SYNOPSIS
                      // ========================================================

                      if (manga.description.isNotEmpty) ...[
                        const SizedBox(height: 18),

                        const Text(
                          'Synopsis',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        AnimatedSize(
                          duration: const Duration(
                            milliseconds: 220,
                          ),
                          curve: Curves.easeOut,
                          alignment:
                              Alignment.topCenter,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                manga.description,
                                maxLines:
                                    _synopsisExpanded
                                        ? null
                                        : 2,
                                overflow:
                                    _synopsisExpanded
                                        ? TextOverflow
                                            .visible
                                        : TextOverflow
                                            .ellipsis,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white70,
                                  height: 1.5,
                                  fontSize: 14,
                                ),
                              ),

                              const SizedBox(height: 6),

                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _synopsisExpanded =
                                        !_synopsisExpanded;
                                  });
                                },
                                child: Text(
                                  _synopsisExpanded
                                      ? 'Read less'
                                      : 'Read more',
                                  style:
                                      const TextStyle(
                                    color: tomoPink,
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ========================================================
                      // SHOW DETAILS
                      // ========================================================

                      const SizedBox(height: 18),

                      AnimatedSize(
                        duration: const Duration(
                          milliseconds: 220,
                        ),
                        curve: Curves.easeOut,
                        alignment:
                            Alignment.topCenter,
                        child: _detailsExpanded
                            ? Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  // ------------------------------------------------
                                  // AUTHORS
                                  // ------------------------------------------------

                                  if (manga
                                      .authors
                                      .isNotEmpty) ...[
                                    const Text(
                                      'Authors',
                                      style:
                                          TextStyle(
                                        fontSize: 19,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 8,
                                    ),

                                    Text(
                                      manga
                                          .authors
                                          .join(', '),
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 18,
                                    ),
                                  ],

                                  // ------------------------------------------------
                                  // INFORMATION
                                  // ------------------------------------------------

                                  if (manga
                                          .type
                                          .isNotEmpty ||
                                      manga
                                          .status
                                          .isNotEmpty ||
                                      manga
                                          .released
                                          .isNotEmpty)
                                    Container(
                                      width:
                                          double.infinity,
                                      padding:
                                          const EdgeInsets
                                              .all(15),
                                      decoration:
                                          BoxDecoration(
                                        color: tomoCard,
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          16,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          if (manga
                                              .type
                                              .isNotEmpty)
                                            _MangaInfoRow(
                                              label: 'Type',
                                              value: manga
                                                  .type,
                                            ),

                                          if (manga
                                              .status
                                              .isNotEmpty)
                                            _MangaInfoRow(
                                              label:
                                                  'Status',
                                              value: manga
                                                  .status,
                                            ),

                                          if (manga
                                              .released
                                              .isNotEmpty)
                                            _MangaInfoRow(
                                              label:
                                                  'Released',
                                              value: manga
                                                  .released,
                                            ),

                                          _MangaInfoRow(
                                            label:
                                                'Official Translation',
                                            value: manga
                                                    .officialTranslation
                                                ? 'Yes'
                                                : 'No',
                                          ),

                                          _MangaInfoRow(
                                            label:
                                                'Anime Adaptation',
                                            value: manga
                                                    .animeAdaptation
                                                ? 'Yes'
                                                : 'No',
                                          ),

                                          _MangaInfoRow(
                                            label: 'Adult Content',
                                            value: manga.adultContent
                                                ? 'Yes'
                                                : 'No',
                                          ),
                                        ],
                                      ),
                                    ),

                                  // ------------------------------------------------
                                  // TAGS
                                  // ------------------------------------------------

                                  if (manga
                                      .tags
                                      .isNotEmpty) ...[
                                    const SizedBox(
                                      height: 20,
                                    ),

                                    const Text(
                                      'Tags',
                                      style:
                                          TextStyle(
                                        fontSize: 19,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 10,
                                    ),

                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 7,
                                      children: manga
                                          .tags
                                          .map(
                                            (tag) {
                                              return Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal:
                                                      10,
                                                  vertical:
                                                      6,
                                                ),
                                                decoration:
                                                    BoxDecoration(
                                                  color: tomoPink
                                                      .withOpacity(
                                                    0.10,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                    9,
                                                  ),
                                                  border:
                                                      Border.all(
                                                    color: tomoPink
                                                        .withOpacity(
                                                      0.18,
                                                    ),
                                                  ),
                                                ),
                                                child:
                                                    Text(
                                                  tag,
                                                  style:
                                                      const TextStyle(
                                                    color:
                                                        Colors.white70,
                                                    fontSize:
                                                        12,
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                          .toList(),
                                    ),
                                  ],

                                  const SizedBox(
                                    height: 18,
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      // ========================================================
                      // DETAILS BUTTON
                      // ========================================================

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _detailsExpanded =
                                  !_detailsExpanded;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                tomoPink,
                            side: const BorderSide(
                              color: tomoPink,
                              width: 1,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 13,
                            ),
                          ),
                          child: Text(
                            _detailsExpanded
                                ? 'Hide details'
                                : 'Show details',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ========================================================
                      // CONTINUE READING
                      // ========================================================

                      if (lastChapterId != null &&
                          chapters.any(
                            (chapter) =>
                                chapter.id ==
                                lastChapterId,
                          ))
                        Builder(
                          builder: (context) {
                            final lastChapter =
                                chapters.firstWhere(
                              (chapter) =>
                                  chapter.id ==
                                  lastChapterId,
                            );

                            return SizedBox(
                              width:
                                  double.infinity,
                              height: 50,
                              child:
                                  FilledButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MangaReaderPage(
                                        manga:
                                            manga,
                                        chapter:
                                            lastChapter,
                                        chapters:
                                            chapters,
                                      ),
                                    ),
                                  );

                                  await _loadProgress();
                                },
                                icon: const Icon(
                                  Icons
                                      .play_arrow_rounded,
                                ),
                                label: Text(
                                  'Continue — ${lastChapter.title}',
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                ),
                                style:
                                    FilledButton.styleFrom(
                                  backgroundColor:
                                      tomoPink,
                                  foregroundColor:
                                      Colors.white,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      14,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 22),

                      // ========================================================
                      // CHAPTERS
                      // ========================================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            'Chapters',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (!loadingChapters &&
                          chapters.isNotEmpty)
                        TextField(
                          controller:
                              _chapterSearchController,
                          onChanged: (value) {
                            setState(() {
                              _chapterSearch =
                                  value;
                            });
                          },
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration:
                              InputDecoration(
                            hintText:
                                'Search chapter...',
                            hintStyle:
                                const TextStyle(
                              color:
                                  Colors.white38,
                            ),
                            prefixIcon:
                                const Icon(
                              Icons.search,
                              color:
                                  Colors.white38,
                              size: 21,
                            ),
                            suffixIcon:
                                _chapterSearch
                                        .isNotEmpty
                                    ? IconButton(
                                        onPressed: () {
                                          _chapterSearchController
                                              .clear();

                                          setState(() {
                                            _chapterSearch =
                                                '';
                                          });
                                        },
                                        icon:
                                            const Icon(
                                          Icons.close,
                                          color:
                                              Colors.white38,
                                          size: 19,
                                        ),
                                      )
                                    : null,
                            filled: true,
                            fillColor: tomoCard,
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                              borderSide:
                                  BorderSide.none,
                            ),
                            enabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                              borderSide:
                                  BorderSide.none,
                            ),
                            focusedBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                              borderSide:
                                  const BorderSide(
                                color: tomoPink,
                                width: 1,
                              ),
                            ),
                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // ========================================================
                      // PROGRESS
                      // ========================================================

                      if (!loadingChapters &&
                          chapterError == null &&
                          totalCount > 0)
                        Container(
                          padding:
                              const EdgeInsets.fromLTRB(
                            16,
                            14,
                            16,
                            13,
                          ),
                          decoration:
                              BoxDecoration(
                            color: tomoCard,
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                children: [
                                  const Text(
                                    'Progress',
                                    style:
                                        TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                      color: Colors
                                          .white70,
                                    ),
                                  ),
                                  Text(
                                    '$readCount of $totalCount read',
                                    style:
                                        const TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                      color: Colors
                                          .white54,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 9),

                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(
                                  99,
                                ),
                                child:
                                    LinearProgressIndicator(
                                  value:
                                      totalCount == 0
                                          ? 0
                                          : readCount /
                                              totalCount,
                                  minHeight: 7,
                                  backgroundColor:
                                      Colors.white10,
                                  valueColor:
                                      const AlwaysStoppedAnimation<
                                          Color>(
                                    tomoPink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ================================================================
              // CHAPTER STATES
              // ================================================================

              if (loadingChapters)
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    30,
                  ),
                  sliver:
                      SliverToBoxAdapter(
                    child: Container(
                      padding:
                          const EdgeInsets.all(24),
                      decoration:
                          BoxDecoration(
                        color: tomoCard,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: const Column(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: tomoPink,
                            ),
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Loading chapters...',
                            style:
                                TextStyle(
                              color:
                                  Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (chapterError != null)
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    30,
                  ),
                  sliver:
                      SliverToBoxAdapter(
                    child: Container(
                      padding:
                          const EdgeInsets.all(20),
                      decoration:
                          BoxDecoration(
                        color: tomoCard,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color:
                                Colors.white38,
                            size: 34,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text(
                            'Could not load chapters.',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            chapterError!,
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          OutlinedButton(
                            onPressed:
                                loadChapters,
                            child:
                                const Text(
                              'Retry',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (chapters.isEmpty)
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    30,
                  ),
                  sliver:
                      SliverToBoxAdapter(
                    child: Container(
                      padding:
                          const EdgeInsets.all(24),
                      decoration:
                          BoxDecoration(
                        color: tomoCard,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: const Text(
                        'No chapters found.',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              Colors.white54,
                        ),
                      ),
                    ),
                  ),
                )
              else if (_filteredChapters.isEmpty)
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    30,
                  ),
                  sliver:
                      SliverToBoxAdapter(
                    child: Container(
                      padding:
                          const EdgeInsets.all(24),
                      decoration:
                          BoxDecoration(
                        color: tomoCard,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: const Text(
                        'No chapters match your search.',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              Colors.white54,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    30,
                  ),
                  sliver:
                      SliverList.builder(
                    itemCount:
                        _filteredChapters.length,
                    itemBuilder:
                        (context, index) {
                      final chapter =
                          _filteredChapters[
                              index];

                      final isRead =
                          readChapters.contains(
                        chapter.id,
                      );

                      return Material(
                        color: tomoCard,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MangaReaderPage(
                                  manga:
                                      manga,
                                  chapter:
                                      chapter,
                                  chapters:
                                      chapters,
                                ),
                              ),
                            );

                            await _loadProgress();
                          },
                          child: Container(
                            decoration:
                                BoxDecoration(
                              border: Border(
                                bottom: index ==
                                        _filteredChapters
                                                .length -
                                            1
                                    ? BorderSide.none
                                    : const BorderSide(
                                        color:
                                            Colors
                                                .white10,
                                        width: 1,
                                      ),
                              ),
                            ),
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration:
                                      BoxDecoration(
                                    color: tomoPink
                                        .withOpacity(
                                      0.12,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      10,
                                    ),
                                  ),
                                  child:
                                      const Icon(
                                    Icons
                                        .menu_book_outlined,
                                    size: 19,
                                    color:
                                        tomoPink,
                                  ),
                                ),

                                const SizedBox(
                                  width: 13,
                                ),

                                Expanded(
                                  child: Text(
                                    chapter.title,
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                      color: isRead
                                          ? Colors
                                              .white54
                                          : Colors
                                              .white,
                                    ),
                                  ),
                                ),

                                IconButton(
                                  onPressed: () =>
                                      _toggleChapterRead(
                                    chapter.id,
                                  ),
                                  tooltip: isRead
                                      ? 'Mark as unread'
                                      : 'Mark as read',
                                  padding:
                                      EdgeInsets
                                          .zero,
                                  constraints:
                                      const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  icon: Icon(
                                    isRead
                                        ? Icons
                                            .check_circle
                                        : Icons
                                            .circle_outlined,
                                    color: isRead
                                        ? Colors
                                            .white30
                                        : Colors
                                            .white24,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MangaInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _MangaInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style:
                  const TextStyle(
                color:
                    Colors.white38,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize: 13,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TOMO READER
// ============================================================