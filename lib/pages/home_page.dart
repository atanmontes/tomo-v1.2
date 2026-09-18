import 'dart:async';

import 'package:flutter/material.dart';

import '../models/manga/manga.dart';
import '../services/manga/manga_banner_service.dart';
import '../services/manga/manga_service.dart';
import '../state/library_scope.dart';
import '../theme/tomo_theme.dart';
import '../widgets/manga/tomo_network_image.dart';
import 'manga/reader_launcher.dart';
import 'library_page.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  Key _homeKey = UniqueKey();

  void _onNavigationChanged(int index) {
    if (index == 0 && _selectedIndex == 0) {
      setState(() {
        _homeKey = UniqueKey();
      });
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tomoBackground,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeContent(key: _homeKey),
          const SearchPage(),
          const LibraryPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tomoElevated,
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onNavigationChanged,
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 68,
          indicatorColor: tomoPink.withOpacity(0.18),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(
                Icons.home_rounded,
                color: tomoPink,
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(
                Icons.search_rounded,
                color: tomoPink,
              ),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.collections_bookmark_outlined),
              selectedIcon: Icon(
                Icons.collections_bookmark_rounded,
                color: tomoPink,
              ),
              label: 'Library',
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// HOME CONTENT
// ==========================================================================

class _HomeContent extends StatefulWidget {
  const _HomeContent({super.key});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  List<MangaItem> latestManga = [];
  bool loadingLatest = false;

  final MangaService _mangaService = MangaService();

  @override
  void initState() {
    super.initState();

    _loadLatest();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      LibraryScope.read(context).checkLibraryUpdates();
    });
  }

  Future<void> _loadLatest() async {
    if (!mounted) return;

    setState(() {
      loadingLatest = true;
    });

    try {
      final results = await _mangaService.getLatestManga();

      if (!mounted) return;

      setState(() {
        latestManga = results;
        loadingLatest = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        latestManga = [];
        loadingLatest = false;
      });
    }
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

  Future<void> _continueManga(MangaItem manga) async {
    await openMangaOrContinue(
      context,
      manga,
      preferContinue: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            // ------------------------------------------------------------
            // TOMO HEADER
            // ------------------------------------------------------------

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 36,
                    ),
                    children: [
                      TextSpan(
                        text: 'TOM',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: 'O',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          color: tomoPink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Padding(
                  padding: EdgeInsets.only(bottom: 5),
                  child: Text(
                    'Welcome back.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ------------------------------------------------------------
            // HOME CONTENT
            // ------------------------------------------------------------

            Expanded(
              child: _HomeContentSections(
                latestManga: latestManga,
                loadingLatest: loadingLatest,
                onOpen: _openManga,
                onContinue: _continueManga,
                onLibraryToggle: _toggleLibrary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// HOME SECTIONS
// ==========================================================================

class _HomeContentSections extends StatelessWidget {
  final List<MangaItem> latestManga;
  final bool loadingLatest;
  final Future<void> Function(MangaItem) onOpen;
  final Future<void> Function(MangaItem) onContinue;
  final Future<void> Function(MangaItem) onLibraryToggle;

  const _HomeContentSections({
    required this.latestManga,
    required this.loadingLatest,
    required this.onOpen,
    required this.onContinue,
    required this.onLibraryToggle,
  });

  @override
  Widget build(BuildContext context) {
    final store = LibraryScope.of(context);

    final continueReading = store.items
        .where(
          (manga) => store.readCountFor(manga.id) > 0,
        )
        .take(6)
        .toList();

    final featuredManga = latestManga
        .where(
          (manga) => !store.isInLibrary(manga.id),
        )
        .take(5)
        .toList();

    final featuredIds =
        featuredManga.map((manga) => manga.id).toSet();

    // Latest Updates no debe repetir lo que ya se muestra en
    // Featured.
    final updatesManga = latestManga
        .where(
          (manga) => !featuredIds.contains(manga.id),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (loadingLatest)
          const SizedBox(
            height: 360,
            child: Center(
              child: CircularProgressIndicator(
                color: tomoPink,
              ),
            ),
          )
        else if (featuredManga.isEmpty)
          Container(
            height: 180,
            alignment: Alignment.center,
            child: const Text(
              'No featured manga available right now.',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          )
        else
          _FeaturedMangaCarousel(
            manga: featuredManga,
            onOpen: onOpen,
            onSubscribe: onLibraryToggle,
          ),

        const SizedBox(height: 30),

        // ------------------------------------------------------------------
        // CONTINUE READING
        // ------------------------------------------------------------------

        if (continueReading.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Continue Reading',
            icon: Icons.menu_book_rounded,
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 218,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: continueReading.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final manga = continueReading[index];

                return _HomeMangaTile(
                  manga: manga,
                  readCount: store.readCountFor(manga.id),
                  hasUpdate: store.hasUpdate(manga.id),
                  onTap: () => onContinue(manga),
                );
              },
            ),
          ),

          const SizedBox(height: 30),
        ],

        // ------------------------------------------------------------------
        // LATEST UPDATES
        // ------------------------------------------------------------------

        const _SectionTitle(
          title: 'Latest Updates',
          icon: Icons.update_rounded,
        ),

        const SizedBox(height: 12),

        if (loadingLatest)
          const SizedBox(
            height: 150,
            child: Center(
              child: CircularProgressIndicator(
                color: tomoPink,
              ),
            ),
          )
        else if (updatesManga.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No updates available right now.',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: updatesManga.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 18,
              mainAxisExtent: 215,
            ),
            itemBuilder: (context, index) {
              final manga = updatesManga[index];

              return RepaintBoundary(
                child: _HomeLatestTile(
                  manga: manga,
                  hasUpdate: store.hasUpdate(manga.id),
                  isInLibrary: store.isInLibrary(manga.id),
                  libraryBusy: store.busyIds.contains(manga.id),
                  onTap: () => onOpen(manga),
                  onLibraryToggle: () =>
                      onLibraryToggle(manga),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ==========================================================================
// SECTION TITLE
// ==========================================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 24,
          decoration: BoxDecoration(
            color: tomoPink,
            borderRadius: BorderRadius.circular(99),
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
// FEATURED MANGA CAROUSEL
// ==========================================================================

class _FeaturedMangaCarousel extends StatefulWidget {
  final List<MangaItem> manga;
  final Future<void> Function(MangaItem) onOpen;
  final Future<void> Function(MangaItem) onSubscribe;

  const _FeaturedMangaCarousel({
    required this.manga,
    required this.onOpen,
    required this.onSubscribe,
  });

  @override
  State<_FeaturedMangaCarousel> createState() =>
      _FeaturedMangaCarouselState();
}

class _FeaturedMangaCarouselState
    extends State<_FeaturedMangaCarousel> {
  late final PageController _pageController;

  Timer? _autoSlideTimer;
  int _currentPage = 0;

  // manga.id -> resultado de AniList (banner y/o cover en alta res)
  final Map<String, MangaBannerResult?> _images = {};

  @override
  void initState() {
    super.initState();

    _pageController = PageController(
      viewportFraction: 0.96,
    );

    _startAutoSlide();
    _loadBanners();
  }

  @override
  void didUpdateWidget(
    covariant _FeaturedMangaCarousel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    _loadBanners();
  }

  void _loadBanners() {
    for (final manga in widget.manga) {
      if (_images.containsKey(manga.id)) continue;

      // Reservamos el slot antes del await para no disparar
      // el mismo fetch dos veces.
      _images[manga.id] = null;

      MangaBannerService.fetchImages(
        manga.title,
        altTitles: manga.associatedNames,
      ).then((result) {
        if (!mounted || result.isEmpty) return;

        setState(() {
          _images[manga.id] = result;
        });
      });
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();

    if (widget.manga.length <= 1) {
      return;
    }

    _autoSlideTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted || !_pageController.hasClients) {
          return;
        }

        final nextPage =
            (_currentPage + 1) % widget.manga.length;

        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  void _onPageChanged(int index) {
    if (!mounted) return;

    setState(() {
      _currentPage = index;
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 382,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.manga.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final manga = widget.manga[index];

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FeaturedMangaHero(
                  manga: manga,
                  images: _images[manga.id],
                  onStartReading: () =>
                      widget.onOpen(manga),
                  onSubscribe: () =>
                      widget.onSubscribe(manga),
                ),
              );
            },
          ),
        ),
        if (widget.manga.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.manga.length,
              (index) {
                final selected = index == _currentPage;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 3,
                  ),
                  width: selected ? 22 : 6,
                  height: 5,
                  decoration: BoxDecoration(
                    color: selected
                        ? tomoPink
                        : Colors.white24,
                    borderRadius:
                        BorderRadius.circular(99),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ==========================================================================
// FEATURED MANGA HERO
// ==========================================================================

class _FeaturedMangaHero extends StatelessWidget {
  final MangaItem manga;
  final MangaBannerResult? images;
  final VoidCallback onStartReading;
  final VoidCallback onSubscribe;

  const _FeaturedMangaHero({
    required this.manga,
    this.images,
    required this.onStartReading,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onStartReading,
        borderRadius: BorderRadius.circular(5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (manga.cover.isNotEmpty)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.20,
                    child: Transform.scale(
                      scale: 1.12,
                      child: TomoNetworkImage(
                        url: manga.cover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        cacheWidth: 700,
                      ),
                    ),
                  ),
                ),

              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 300,
                  ),
                  child: images?.bannerImage != null
                      ? TomoNetworkImage(
                          key: ValueKey(images!.bannerImage),
                          url: images!.bannerImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: 900,
                        )
                      : images?.coverImage != null
                          ? TomoNetworkImage(
                              key: ValueKey(images!.coverImage),
                              url: images!.coverImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              cacheWidth: 900,
                            )
                          : manga.cover.isEmpty
                              ? Container(
                                  key: const ValueKey(
                                    'featured-placeholder',
                                  ),
                                  color: tomoCard,
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    color: Colors.white24,
                                    size: 50,
                                  ),
                                )
                              : TomoNetworkImage(
                                  key: const ValueKey(
                                    'featured-cover',
                                  ),
                                  url: manga.cover,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  cacheWidth: 900,
                                ),
                ),
              ),

              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [
                        0.0,
                        0.20,
                        0.48,
                        0.72,
                        1.0,
                      ],
                      colors: [
                        Colors.black.withOpacity(0.42),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.50),
                        Colors.black.withOpacity(0.97),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [
                        0.0,
                        0.42,
                        1.0,
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 3,
                          decoration: BoxDecoration(
                            color: tomoPink,
                            borderRadius:
                                BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          width: 5,
                          height: 3,
                          decoration: BoxDecoration(
                            color: tomoPink.withOpacity(0.45),
                            borderRadius:
                                BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 9),

                    Text(
                      manga.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                        letterSpacing: -0.7,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 12,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: FilledButton.icon(
                              onPressed: onStartReading,
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 21,
                              ),
                              label: const Text(
                                'Start Reading',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: tomoPink,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor:
                                    tomoPink.withOpacity(0.28),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        SizedBox(
                          width: 48,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: onSubscribe,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Colors.black.withOpacity(0.38),
                              side: BorderSide(
                                color:
                                    Colors.white.withOpacity(0.38),
                              ),
                              padding: EdgeInsets.zero,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                            ),
                            child: const Icon(
                              Icons.bookmark_add_outlined,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// CONTINUE READING TILE
// ==========================================================================

class _HomeMangaTile extends StatelessWidget {
  final MangaItem manga;
  final VoidCallback onTap;
  final bool hasUpdate;
  final int readCount;

  const _HomeMangaTile({
    required this.manga,
    required this.onTap,
    required this.readCount,
    this.hasUpdate = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 122,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    width: 122,
                    height: 168,
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
                            width: 122,
                            height: 168,
                            fit: BoxFit.cover,
                            cacheWidth:
                                (122 *
                                        MediaQuery
                                            .devicePixelRatioOf(
                                          context,
                                        ) *
                                        1.15)
                                    .round(),
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 7),

            Text(
              manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              '$readCount ${readCount == 1 ? 'chapter' : 'chapters'} read',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.white38,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// LATEST TILE
// ==========================================================================

class _HomeLatestTile extends StatelessWidget {
  final MangaItem manga;
  final bool hasUpdate;
  final bool isInLibrary;
  final bool libraryBusy;
  final VoidCallback onTap;
  final VoidCallback onLibraryToggle;

  const _HomeLatestTile({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: manga.cover.isEmpty
                        ? Container(
                            color: tomoCard,
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white24,
                              size: 34,
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return TomoNetworkImage(
                                url: manga.cover,
                                fit: BoxFit.cover,
                                width: 400,
                                height: 600,
                                cacheWidth: (constraints
                                            .maxWidth *
                                        MediaQuery
                                            .devicePixelRatioOf(
                                          context,
                                        ) *
                                        1.15)
                                    .round(),
                              );
                            },
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Material(
                    color: Colors.black.withOpacity(0.72),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: libraryBusy
                          ? null
                          : onLibraryToggle,
                      customBorder: const CircleBorder(),
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
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
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
              overflow: TextOverflow.ellipsis,
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