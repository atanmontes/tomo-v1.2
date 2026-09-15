import 'dart:async';
import 'package:flutter/material.dart';
import '../models/manga/manga.dart';
import '../models/manga/manga_search_filters.dart';
import '../services/manga/manga_service.dart';
import '../state/library_scope.dart';
import '../theme/tomo_theme.dart';
import '../widgets/manga/manga_card.dart';
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
  List<MangaItem> searchResults = [];
  MangaSearchFilters _searchFilters =
      const MangaSearchFilters();
  String search = '';
  bool searching = false;
  bool loadingMore = false;
  bool hasMoreResults = true;
  int _searchOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      LibraryScope.read(context).checkLibraryUpdates();
    });
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

  Future<void> _openExploreFilters({
    String? tag,
    String? sort,
  }) async {
    final initial = MangaSearchFilters(
      sort: sort ?? _searchFilters.sort,
      order: _searchFilters.order,
      official: _searchFilters.official,
      animeAdaptation:
          _searchFilters.animeAdaptation,
      adultContent: _searchFilters.adultContent,
      status: _searchFilters.status,
      type: _searchFilters.type,
      tags: tag != null
          ? [tag]
          : _searchFilters.tags,
    );
    final selected =
        await showModalBottomSheet<MangaSearchFilters>(
      context: context,
      backgroundColor: tomoCard,
      isScrollControlled: true,
      builder: (_) {
        return _SearchFiltersSheet(
          initial: initial,
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
    const genres = [
      'Action',
      'Adventure',
      'Comedy',
      'Drama',
      'Fantasy',
      'Horror',
      'Isekai',
      'Mystery',
      'Romance',
      'Sci-fi',
      'Slice of Life',
      'Supernatural',
    ];
    return ListView(
      padding: const EdgeInsets.only(
        bottom: 24,
      ),
      children: [
        const _SearchSectionTitle(
          title: 'Explore',
          icon: Icons.explore_rounded,
        ),
        const SizedBox(height: 20),
        const Text(
          'Genres',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: genres.map((genre) {
            return _ExploreChip(
              label: genre,
              onTap: () {
                _openExploreFilters(
                  tag: genre,
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        const Text(
          'Quick Filters',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ExploreChip(
              label: 'Popularity',
              icon:
                  Icons.local_fire_department_rounded,
              onTap: () {
                _openExploreFilters(
                  sort: 'Popularity',
                );
              },
            ),
            _ExploreChip(
              label: 'Recently Added',
              icon: Icons.fiber_new_rounded,
              onTap: () {
                _openExploreFilters(
                  sort: 'Recently Added',
                );
              },
            ),
            _ExploreChip(
              label: 'Latest Updates',
              icon: Icons.update_rounded,
              onTap: () {
                _openExploreFilters(
                  sort: 'Latest Updates',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tomoCard,
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.search_rounded,
                color: tomoPink,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Looking for something specific?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Use the search bar or filters to '
                      'find exactly what you want to read.',
                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(0.55),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class _ExploreChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _ExploreChip({
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tomoCard,
      borderRadius:
          BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(10),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: tomoPink,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                      color: Colors.white,
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

  Future<void> openPicker(
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
              openPicker(context),
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