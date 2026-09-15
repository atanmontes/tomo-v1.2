import 'dart:async';

import 'package:flutter/material.dart';

import '../models/manga/manga.dart';
import '../models/manga/manga_search_filters.dart';
import '../services/manga/manga_service.dart';
import '../state/library_scope.dart';
import '../theme/tomo_theme.dart';
import '../widgets/manga/manga_card.dart';
import '../widgets/manga/tomo_network_image.dart';
import 'manga/reader_launcher.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController =
      TextEditingController();

  final MangaService _mangaService = MangaService();

  Timer? _searchDebounce;

  List<MangaItem> browseManga = [];
  List<MangaItem> searchResults = [];

  MangaSearchFilters _searchFilters =
      const MangaSearchFilters();

  String search = '';

  bool loadingBrowse = false;
  bool searching = false;
  bool loadingMore = false;
  bool hasMoreResults = true;

  int _searchOffset = 0;

  @override
  void initState() {
    super.initState();

    _loadBrowseManga();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      LibraryScope.read(context).checkLibraryUpdates();
    });
  }

  Future<void> _loadBrowseManga() async {
    if (!mounted) return;

    setState(() {
      loadingBrowse = true;
    });

    try {
      final results = await _mangaService.getLatestManga();
      if (!mounted) return;

      setState(() {
        browseManga = results;
        loadingBrowse = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        browseManga = [];
        loadingBrowse = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      search = value;
    });

    _searchDebounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        searching = false;
        loadingMore = false;
        hasMoreResults = true;
        _searchOffset = 0;
      });

      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchManga(query),
    );
  }

  Future<void> _searchManga(
    String query, {
    bool loadMore = false,
  }) async {
    if (!mounted) return;

    if (loadMore) {
      if (loadingMore || !hasMoreResults) {
        return;
      }

      setState(() {
        loadingMore = true;
      });
    } else {
      setState(() {
        searching = true;
        loadingMore = false;
        hasMoreResults = true;
        _searchOffset = 0;
        searchResults = [];
      });
    }

    final offset = loadMore ? _searchOffset : 0;

    try {
      final results = await _mangaService.searchManga(
        query,
        filters: _searchFilters,
        offset: offset,
      );

      if (!mounted || search.trim() != query) {
        return;
      }

      setState(() {
        if (loadMore) {
          final existingIds =
              searchResults.map((manga) => manga.id).toSet();

          searchResults.addAll(
            results.where(
              (manga) => !existingIds.contains(manga.id),
            ),
          );
        } else {
          searchResults = results;
        }

        _searchOffset += results.length;

        hasMoreResults = results.length == 32;

        searching = false;
        loadingMore = false;
      });
    } catch (_) {
      if (!mounted || search.trim() != query) {
        return;
      }

      setState(() {
        if (loadMore) {
          loadingMore = false;
        } else {
          searchResults = [];
          searching = false;
        }
      });
    }
  }

  Future<void> _loadMoreResults() async {
    await _searchManga(
      search.trim(),
      loadMore: true,
    );
  }

  Future<void> _openSearchFilters() async {
    final selected =
        await showModalBottomSheet<MangaSearchFilters>(
      context: context,
      backgroundColor: tomoCard,
      isScrollControlled: true,
      builder: (_) {
        return _SearchFiltersSheet(
          initial: _searchFilters,
        );
      },
    );

    if (selected == null) return;

    setState(() {
      _searchFilters = selected;
    });

    _searchDebounce?.cancel();

    await _searchManga(search.trim());
  }

  bool _isInLibrary(MangaItem manga) {
    return LibraryScope.of(context).isInLibrary(manga.id);
  }

  Future<void> _toggleLibrary(MangaItem manga) async {
    await LibraryScope.read(context).toggle(manga);
  }

  Future<void> _openManga(MangaItem manga) async {
    await openMangaOrContinue(
      context,
      manga,
    );
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      search = '';
      searchResults = [];
      searching = false;
      loadingMore = false;
      hasMoreResults = true;
      _searchOffset = 0;
      _searchFilters = const MangaSearchFilters();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch =
        search.trim().isNotEmpty ||
        _searchFilters.hasFilters;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------------------
            // HEADER
            // ------------------------------------------------------------

            const Text(
              'Search',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              hasSearch
                  ? 'Search results'
                  : 'Find your next manga.',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 16),

            // ------------------------------------------------------------
            // SEARCH BAR
            // ------------------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search manga...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white38,
                        size: 21,
                      ),
                      suffixIcon: search.isNotEmpty
                          ? IconButton(
                              onPressed: _clearSearch,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: tomoCard,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: tomoPink,
                          width: 1,
                        ),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Material(
                  color: _searchFilters.hasFilters
                      ? tomoPink.withOpacity(0.14)
                      : tomoCard,
                  borderRadius:
                      BorderRadius.circular(18),
                  child: InkWell(
                    onTap: _openSearchFilters,
                    borderRadius:
                        BorderRadius.circular(18),
                    child: SizedBox(
                      width: 50,
                      height: 52,
                      child: Icon(
                        Icons.tune_rounded,
                        color:
                            _searchFilters.hasFilters
                                ? tomoPink
                                : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ------------------------------------------------------------
            // CONTENT
            // ------------------------------------------------------------

            Expanded(
              child: searching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: tomoPink,
                      ),
                    )
                  : hasSearch
                      ? _buildSearchResults()
                      : _buildBrowseContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseContent() {
    return ListView(
      padding: const EdgeInsets.only(
        bottom: 24,
      ),
      children: [
        const _SearchSectionTitle(
          title: 'Latest Updates',
          icon: Icons.update_rounded,
        ),

        const SizedBox(height: 12),

        if (loadingBrowse)
          const SizedBox(
            height: 250,
            child: Center(
              child: CircularProgressIndicator(
                color: tomoPink,
              ),
            ),
          )
        else if (browseManga.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 50,
            ),
            child: Center(
              child: Text(
                'No manga available right now.',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount: browseManga.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 18,
              mainAxisExtent: 215,
            ),
            itemBuilder: (context, index) {
              final manga = browseManga[index];

              final store =
                  LibraryScope.of(context);

              return RepaintBoundary(
                child: _SearchBrowseTile(
                  manga: manga,
                  isInLibrary:
                      store.isInLibrary(manga.id),
                  libraryBusy:
                      store.busyIds.contains(
                    manga.id,
                  ),
                  hasUpdate:
                      store.hasUpdate(manga.id),
                  onTap: () =>
                      _openManga(manga),
                  onLibraryToggle: () =>
                      _toggleLibrary(manga),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No manga found.',
          style: TextStyle(
            color: Colors.white54,
          ),
        ),
      );
    }

    return ListView.separated(
      cacheExtent: 500,
      padding: const EdgeInsets.only(
        bottom: 24,
      ),
      itemCount:
          searchResults.length +
          (hasMoreResults ? 1 : 0),
      separatorBuilder: (_, index) {
        if (index >= searchResults.length) {
          return const SizedBox.shrink();
        }

        return const SizedBox(height: 10);
      },
      itemBuilder: (context, index) {
        if (index >= searchResults.length) {
          return Padding(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 12,
            ),
            child: Center(
              child: Material(
                color: tomoCard,
                borderRadius:
                    BorderRadius.circular(18),
                child: InkWell(
                  onTap: loadingMore
                      ? null
                      : _loadMoreResults,
                  borderRadius:
                      BorderRadius.circular(14),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 13,
                    ),
                    child: loadingMore
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: tomoPink,
                            ),
                          )
                        : const Text(
                            'Load More',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        }

        final manga = searchResults[index];

        return RepaintBoundary(
          child: MangaCard(
            manga: manga,
            onTap: () => _openManga(manga),
            isInLibrary:
                _isInLibrary(manga),
            libraryBusy:
                LibraryScope.of(context)
                    .busyIds
                    .contains(manga.id),
            onLibraryToggle: () {
              _toggleLibrary(manga);
            },
            showAuthor: false,
          ),
        );
      },
    );
  }
}

// ==========================================================================
// SEARCH SECTION TITLE
// ==========================================================================

class _SearchSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SearchSectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 24,
          decoration: BoxDecoration(
            color: tomoPink,
            borderRadius:
                BorderRadius.circular(99),
          ),
        ),

        const SizedBox(width: 10),

        Icon(
          icon,
          color: tomoPink,
          size: 19,
        ),

        const SizedBox(width: 7),

        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// SEARCH BROWSE TILE
// ==========================================================================

class _SearchBrowseTile extends StatelessWidget {
  final MangaItem manga;
  final bool hasUpdate;
  final bool isInLibrary;
  final bool libraryBusy;
  final VoidCallback onTap;
  final VoidCallback onLibraryToggle;

  const _SearchBrowseTile({
    required this.manga,
    required this.hasUpdate,
    required this.isInLibrary,
    required this.libraryBusy,
    required this.onTap,
    required this.onLibraryToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(5),
                    child: manga.cover.isEmpty
                        ? Container(
                            color: tomoCard,
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white24,
                              size: 34,
                            ),
                          )
                        : TomoNetworkImage(
                            url: manga.cover,
                            fit: BoxFit.cover,
                            width: 400,
                            height: 600,
                            cacheWidth: 360,
                          ),
                  ),
                ),

                if (hasUpdate)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tomoPink,
                        borderRadius:
                            BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Material(
                    color: Colors.black
                        .withOpacity(0.72),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: libraryBusy
                          ? null
                          : onLibraryToggle,
                      customBorder:
                          const CircleBorder(),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: libraryBusy
                            ? const Padding(
                                padding:
                                    EdgeInsets.all(8),
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: tomoPink,
                                ),
                              )
                            : Icon(
                                isInLibrary
                                    ? Icons
                                        .check_rounded
                                    : Icons
                                        .add_rounded,
                                size: 19,
                                color: isInLibrary
                                    ? tomoPink
                                    : Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            height: 34,
            child: Text(
              manga.title,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// SEARCH FILTERS
// ==========================================================================

class _SearchFiltersSheet extends StatefulWidget {
  final MangaSearchFilters initial;

  const _SearchFiltersSheet({
    required this.initial,
  });

  @override
  State<_SearchFiltersSheet> createState() =>
      _SearchFiltersSheetState();
}

class _SearchFiltersSheetState
    extends State<_SearchFiltersSheet> {
  late String sort = widget.initial.sort;
  late String order = widget.initial.order;
  late String official = widget.initial.official;
  late String anime =
      widget.initial.animeAdaptation;
  late String adult =
      widget.initial.adultContent;
  late String status = widget.initial.status;
  late String type = widget.initial.type;

  late Set<String> tags =
      {...widget.initial.tags};

  static const sorts = [
    'Best Match',
    'Alphabet',
    'Popularity',
    'Subscribers',
    'Recently Added',
    'Latest Updates',
  ];

  static const tagsList = [
    'Action',
    'Adult',
    'Adventure',
    'Comedy',
    'Doujinshi',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Gender Bender',
    'Harem',
    'Hentai',
    'Historical',
    'Horror',
    'Isekai',
    'Josei',
    'Lolicon',
    'Martial Arts',
    'Mature',
    'Mecha',
    'Mystery',
    'Psychological',
    'Romance',
    'School Life',
    'Sci-fi',
    'Seinen',
    'Shotacon',
    'Shoujo',
    'Shoujo Ai',
    'Shounen',
    'Shounen Ai',
    'Slice of Life',
    'Smut',
    'Sports',
    'Supernatural',
    'Tragedy',
    'Yaoi',
    'Yuri',
    'Other',
  ];

  void _apply() {
    Navigator.pop(
      context,
      MangaSearchFilters(
        sort: sort,
        order: order,
        official: official,
        animeAdaptation: anime,
        adultContent: adult,
        status: status,
        type: type,
        tags: tags.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (_, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              30,
            ),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Search Filters',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        sort = 'Best Match';
                        order = 'Ascending';
                        official = 'Any';
                        anime = 'Any';
                        adult = 'Any';
                        status = 'Any';
                        type = 'Any';
                        tags.clear();
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _FilterDropdown(
                label: 'Sort',
                value: sort,
                values: sorts,
                onChanged: (value) =>
                    setState(() => sort = value),
              ),

              _FilterDropdown(
                label: 'Order',
                value: order,
                values: const [
                  'Ascending',
                  'Descending',
                ],
                onChanged: (value) =>
                    setState(() => order = value),
              ),

              _FilterDropdown(
                label: 'Official Translation',
                value: official,
                values: const [
                  'Any',
                  'True',
                  'False',
                ],
                onChanged: (value) =>
                    setState(() => official = value),
              ),

              _FilterDropdown(
                label: 'Anime Adaptation',
                value: anime,
                values: const [
                  'Any',
                  'True',
                  'False',
                ],
                onChanged: (value) =>
                    setState(() => anime = value),
              ),

              _FilterDropdown(
                label: 'Adult Content',
                value: adult,
                values: const [
                  'Any',
                  'True',
                  'False',
                ],
                onChanged: (value) =>
                    setState(() => adult = value),
              ),

              _FilterDropdown(
                label: 'Series Status',
                value: status,
                values: const [
                  'Any',
                  'Ongoing',
                  'Complete',
                  'Hiatus',
                  'Canceled',
                ],
                onChanged: (value) =>
                    setState(() => status = value),
              ),

              _FilterDropdown(
                label: 'Series Type',
                value: type,
                values: const [
                  'Any',
                  'Manga',
                  'Manhwa',
                  'Manhua',
                  'OEL',
                ],
                onChanged: (value) =>
                    setState(() => type = value),
              ),

              const SizedBox(height: 8),

              const Text(
                'Tags',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tagsList.map((tag) {
                  final selected =
                      tags.contains(tag);

                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          tags.add(tag);
                        } else {
                          tags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _apply,
                  style:
                      FilledButton.styleFrom(
                    backgroundColor: tomoPink,
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================================================
// FILTER DROPDOWN
// ==========================================================================

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  Future<void> _openPicker(
    BuildContext context,
  ) async {
    final selected =
        await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return _ChoiceSheet(
          title: label,
          value: value,
          values: values,
        );
      },
    );

    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 10),
      child: Material(
        color: tomoBackground,
        borderRadius:
            BorderRadius.circular(14),
        child: InkWell(
          onTap: () =>
              _openPicker(context),
          borderRadius:
              BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              14,
              11,
              12,
              11,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons
                      .keyboard_arrow_down_rounded,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// CHOICE SHEET
// ==========================================================================

class _ChoiceSheet extends StatelessWidget {
  final String title;
  final String value;
  final List<String> values;

  const _ChoiceSheet({
    required this.title,
    required this.value,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12,
        ),
        decoration: BoxDecoration(
          color: tomoCard,
          borderRadius:
              BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            14,
            18,
            10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 14),

              Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: values.length,
                  itemBuilder: (_, index) {
                    final item = values[index];
                    final selected =
                        item == value;

                    return Material(
                      color: selected
                          ? tomoPink
                              .withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(14),
                        onTap: () =>
                            Navigator.pop(
                          context,
                          item,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child:
                                    Text(item),
                              ),
                              if (selected)
                                const Icon(
                                  Icons
                                      .check_rounded,
                                  color: tomoPink,
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