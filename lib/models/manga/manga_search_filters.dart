class MangaSearchFilters {
  final String sort;
  final String order;
  final String official;
  final String animeAdaptation;
  final String adultContent;
  final String status;
  final String type;
  final List<String> tags;

  const MangaSearchFilters({
    this.sort = 'Best Match',
    this.order = 'Descending',
    this.official = 'Any',
    this.animeAdaptation = 'Any',
    this.adultContent = 'Any',
    this.status = 'Any',
    this.type = 'Any',
    this.tags = const [],
  });

  bool get hasFilters {
    return sort != 'Best Match' ||
        order != 'Descending' ||
        official != 'Any' ||
        animeAdaptation != 'Any' ||
        adultContent != 'Any' ||
        status != 'Any' ||
        type != 'Any' ||
        tags.isNotEmpty;
  }
}
