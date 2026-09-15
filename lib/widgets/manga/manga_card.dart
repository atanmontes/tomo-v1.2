import 'package:flutter/material.dart';

import '../../models/manga/manga.dart';
import '../../theme/tomo_theme.dart';
import 'tomo_network_image.dart';

class MangaCard extends StatelessWidget {
  final MangaItem manga;
  final VoidCallback onTap;
  final VoidCallback? onLibraryToggle;
  final bool isInLibrary;
  final bool libraryBusy;
  final bool showAuthor;
  final bool hasUpdate;

  const MangaCard({
    super.key,
    required this.manga,
    required this.onTap,
    required this.onLibraryToggle,
    required this.isInLibrary,
    this.libraryBusy = false,
    this.showAuthor = true,
    this.hasUpdate = false,
  });

  String get _authorText {
    if (manga.authors.isEmpty) {
      return 'Unknown author';
    }

    return manga.authors.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tomoCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 108,
          child: Row(
            children: [
              Stack(
                children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
                child: SizedBox(
                  width: 76,
                  height: 108,
                  child: TomoNetworkImage(
                          url: manga.cover,
                          width: 76,
                          height: 108,
                          fit: BoxFit.cover,
                          cacheWidth:
                              (140 *
                                      MediaQuery.devicePixelRatioOf(
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
                  left: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: tomoPink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    12,
                    8,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        manga.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.15,
                        ),
                      ),
                      if (showAuthor) ...[
                        const SizedBox(height: 6),
                        Text(
                          _authorText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12.5,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Material(
                  color: tomoPink,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: libraryBusy ? null : onLibraryToggle,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: libraryBusy
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isInLibrary
                                  ? Icons.remove_rounded
                                  : Icons.add_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                    ),
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