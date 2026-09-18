import 'package:flutter/material.dart';

import '../../core/weebcentral/constants.dart';
import '../../theme/tomo_theme.dart';

class TomoNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  final Widget? placeholder;
  final IconData errorIcon;
  final double errorIconSize;

  const TomoNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
    this.placeholder,
    this.errorIcon = Icons.broken_image_outlined,
    this.errorIconSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return placeholder ??
          Container(
            width: width,
            height: height,
            color: tomoBackground,
            child: Icon(
              Icons.menu_book_rounded,
              size: errorIconSize,
              color: Colors.white24,
            ),
          );
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      filterQuality: filterQuality,
      gaplessPlayback: true,
      headers: weebCentralImageHeaders,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: tomoBackground,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tomoPink,
                ),
              ),
            );
      },
      errorBuilder: (_, __, ___) {
        return Container(
          width: width,
          height: height,
          color: tomoBackground,
          child: Icon(
            errorIcon,
            size: errorIconSize,
            color: Colors.white24,
          ),
        );
      },
    );
  }
}
