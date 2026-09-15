import 'package:flutter/material.dart';

import '../../models/manga/manga.dart';
import '../../state/library_scope.dart';
import '../../theme/tomo_theme.dart';
import '../../widgets/manga/manga_card.dart';
import 'manga/manga_detail_page.dart';

enum _LibraryProgressFilter { all, inProgress, notStarted }
enum _LibrarySort { progress, titleAsc, titleDesc }

class _LibraryFilterSelection {
  final _LibraryProgressFilter progress;
  final _LibrarySort sort;
  final String status;
  final String type;
  final String official;
  final String anime;
  final String adult;

  const _LibraryFilterSelection({
    this.progress = _LibraryProgressFilter.all,
    this.sort = _LibrarySort.progress,
    this.status = 'Any',
    this.type = 'Any',
    this.official = 'Any',
    this.anime = 'Any',
    this.adult = 'Any',
  });
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final TextEditingController _searchController =
      TextEditingController();

  String search = '';
  _LibraryProgressFilter _progressFilter = _LibraryProgressFilter.all;
  _LibrarySort _sort = _LibrarySort.progress;
  String _statusFilter = 'Any';
  String _typeFilter = 'Any';
  String _officialFilter = 'Any';
  String _animeFilter = 'Any';
  String _adultFilter = 'Any';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MangaItem> get library => LibraryScope.of(context).items;

  Future<void> _toggleLibrary(MangaItem manga) async {
    await LibraryScope.read(context).remove(manga.id);
  }

  Future<void> _openManga(MangaItem manga) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaDetailPage(
          manga: manga,
        ),
      ),
    );

  }

  bool _hasProgress(MangaItem manga) {
    return LibraryScope.of(context).readCountFor(manga.id) > 0;
  }

  List<MangaItem> get filteredLibrary {
    final query = search.trim().toLowerCase();

    final result = library.where((manga) {
      final progress = _hasProgress(manga);

      if (_progressFilter == _LibraryProgressFilter.inProgress && !progress) {
        return false;
      }

      if (_progressFilter == _LibraryProgressFilter.notStarted && progress) {
        return false;
      }

      if (_statusFilter != 'Any' &&
          manga.status.toLowerCase() != _statusFilter.toLowerCase()) {
        return false;
      }

      if (_typeFilter != 'Any' &&
          manga.type.toLowerCase() != _typeFilter.toLowerCase()) {
        return false;
      }

      if (_officialFilter != 'Any' &&
          (manga.officialTranslation != (_officialFilter == 'True'))) {
        return false;
      }

      if (_animeFilter != 'Any' &&
          (manga.animeAdaptation != (_animeFilter == 'True'))) {
        return false;
      }

      if (_adultFilter != 'Any' &&
          (manga.adultContent != (_adultFilter == 'True'))) {
        return false;
      }

      if (query.isEmpty) return true;

      final title = manga.title.toLowerCase();
      final authors = manga.authors.join(' ').toLowerCase();
      final tags = manga.tags.join(' ').toLowerCase();

      return title.contains(query) ||
          authors.contains(query) ||
          tags.contains(query);
    }).toList();

    result.sort((a, b) {
      switch (_sort) {
        case _LibrarySort.progress:
          final aProgress = _hasProgress(a);
          final bProgress = _hasProgress(b);
          if (aProgress != bProgress) return aProgress ? -1 : 1;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _LibrarySort.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _LibrarySort.titleDesc:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
      }
    });

    return result;
  }

  String get _filterLabel {
    final parts = <String>[];
    switch (_progressFilter) {
      case _LibraryProgressFilter.all:
        break;
      case _LibraryProgressFilter.inProgress:
        parts.add('In Progress');
        break;
      case _LibraryProgressFilter.notStarted:
        parts.add('Not Started');
        break;
    }
    if (_statusFilter != 'Any') parts.add(_statusFilter);
    if (_typeFilter != 'Any') parts.add(_typeFilter);
    if (_officialFilter != 'Any') parts.add('Official $_officialFilter');
    if (_animeFilter != 'Any') parts.add('Anime $_animeFilter');
    if (_adultFilter != 'Any') parts.add('Adult $_adultFilter');
    return parts.isEmpty ? 'All' : parts.join(' • ');
  }

  bool get _hasActiveFilters =>
      _progressFilter != _LibraryProgressFilter.all ||
      _statusFilter != 'Any' ||
      _typeFilter != 'Any' ||
      _officialFilter != 'Any' ||
      _animeFilter != 'Any' ||
      _adultFilter != 'Any';

  Future<void> _openLibraryFilters() async {
    final selected = await showModalBottomSheet<_LibraryFilterSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LibraryFiltersSheet(
        initial: _LibraryFilterSelection(
          progress: _progressFilter,
          sort: _sort,
          status: _statusFilter,
          type: _typeFilter,
          official: _officialFilter,
          anime: _animeFilter,
          adult: _adultFilter,
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _progressFilter = selected.progress;
      _sort = selected.sort;
      _statusFilter = selected.status;
      _typeFilter = selected.type;
      _officialFilter = selected.official;
      _animeFilter = selected.anime;
      _adultFilter = selected.adult;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mangas = filteredLibrary;

    return Scaffold(
      backgroundColor: tomoBackground,
      appBar: AppBar(
        backgroundColor: tomoBackground,
        elevation: 0,
        title: const Text(
          'My Library',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: _hasActiveFilters
                  ? tomoPink.withOpacity(0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _openLibraryFilters,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.tune_rounded,
                    color: _hasActiveFilters
                        ? tomoPink
                        : Colors.white70,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        search = value;
                      });
                    },
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search your library...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white54,
                      ),
                      suffixIcon: search.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  search = '';
                                });
                              },
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
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              8,
            ),
            child: Row(
              children: [
                Text(
                  _filterLabel,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${mangas.length} manga',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: mangas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            library.isEmpty
                                ? Icons.menu_book_rounded
                                : Icons.search_off_rounded,
                            size: 54,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            library.isEmpty
                                ? 'Your library is empty'
                                : 'No manga found',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            library.isEmpty
                                ? 'Search for a manga on Home and tap the + button to save it here.'
                                : 'Try a different search or filter.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      24,
                    ),
                    cacheExtent: 500,
                    itemCount: mangas.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final manga = mangas[index];

                      return RepaintBoundary(
                        child: MangaCard(
                          manga: manga,
                          onTap: () => _openManga(manga),
                          onLibraryToggle: () {
                            _toggleLibrary(manga);
                          },
                          isInLibrary: true,
                          libraryBusy:
                              LibraryScope.of(context).busyIds.contains(manga.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


class _LibraryFiltersSheet extends StatefulWidget {
  final _LibraryFilterSelection initial;

  const _LibraryFiltersSheet({required this.initial});

  @override
  State<_LibraryFiltersSheet> createState() => _LibraryFiltersSheetState();
}

class _LibraryFiltersSheetState extends State<_LibraryFiltersSheet> {
  late _LibraryProgressFilter progress = widget.initial.progress;
  late _LibrarySort sort = widget.initial.sort;
  late String status = widget.initial.status;
  late String type = widget.initial.type;
  late String official = widget.initial.official;
  late String anime = widget.initial.anime;
  late String adult = widget.initial.adult;

  void _reset() {
    setState(() {
      progress = _LibraryProgressFilter.all;
      sort = _LibrarySort.progress;
      status = 'Any';
      type = 'Any';
      official = 'Any';
      anime = 'Any';
      adult = 'Any';
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      _LibraryFilterSelection(
        progress: progress,
        sort: sort,
        status: status,
        type: type,
        official: official,
        anime: anime,
        adult: adult,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: tomoCard,
          borderRadius: BorderRadius.circular(22),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Library Filters',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Reading Progress', style: _filterHeadingStyle),
              const SizedBox(height: 8),
              _ChoiceWrap<_LibraryProgressFilter>(
                values: const [
                  _LibraryProgressFilter.all,
                  _LibraryProgressFilter.inProgress,
                  _LibraryProgressFilter.notStarted,
                ],
                selected: progress,
                label: (value) => switch (value) {
                  _LibraryProgressFilter.all => 'All',
                  _LibraryProgressFilter.inProgress => 'In Progress',
                  _LibraryProgressFilter.notStarted => 'Not Started',
                },
                onChanged: (value) => setState(() => progress = value),
              ),
              const SizedBox(height: 18),
              const Text('Sort By', style: _filterHeadingStyle),
              const SizedBox(height: 8),
              _ChoiceWrap<_LibrarySort>(
                values: const [
                  _LibrarySort.progress,
                  _LibrarySort.titleAsc,
                  _LibrarySort.titleDesc,
                ],
                selected: sort,
                label: (value) => switch (value) {
                  _LibrarySort.progress => 'Progress First',
                  _LibrarySort.titleAsc => 'Title A–Z',
                  _LibrarySort.titleDesc => 'Title Z–A',
                },
                onChanged: (value) => setState(() => sort = value),
              ),
              const SizedBox(height: 18),
              _LibrarySheetSelect(
                label: 'Series Status',
                value: status,
                values: const ['Any', 'Ongoing', 'Complete', 'Hiatus', 'Canceled'],
                onChanged: (value) => setState(() => status = value),
              ),
              _LibrarySheetSelect(
                label: 'Series Type',
                value: type,
                values: const ['Any', 'Manga', 'Manhwa', 'Manhua', 'OEL'],
                onChanged: (value) => setState(() => type = value),
              ),
              _LibrarySheetSelect(
                label: 'Official Translation',
                value: official,
                values: const ['Any', 'True', 'False'],
                onChanged: (value) => setState(() => official = value),
              ),
              _LibrarySheetSelect(
                label: 'Anime Adaptation',
                value: anime,
                values: const ['Any', 'True', 'False'],
                onChanged: (value) => setState(() => anime = value),
              ),
              _LibrarySheetSelect(
                label: 'Adult Content',
                value: adult,
                values: const ['Any', 'True', 'False'],
                onChanged: (value) => setState(() => adult = value),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _apply,
                  style: FilledButton.styleFrom(backgroundColor: tomoPink),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _filterHeadingStyle = TextStyle(
  color: Colors.white70,
  fontWeight: FontWeight.w700,
);

class _ChoiceWrap<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final active = value == selected;
        return Material(
          color: active ? tomoPink.withOpacity(0.16) : tomoBackground,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                label(value),
                style: TextStyle(
                  color: active ? tomoPink : Colors.white70,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LibrarySheetSelect extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _LibrarySheetSelect({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChoiceSheet(
        title: label,
        value: value,
        values: values,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: tomoBackground,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 3),
                      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
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
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: tomoCard,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 8),
              ...values.map((item) {
                final selected = item == value;
                return Material(
                  color: selected ? tomoPink.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, item),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(item)),
                          if (selected) const Icon(Icons.check_rounded, color: tomoPink),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
