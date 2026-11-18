import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.memCacheWidth,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final Alignment alignment;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final image = url == null || url!.isEmpty
        ? const _ImageFallback()
        : kIsWeb
        // постеры anilibria отдаются без access-control-allow-origin,
        // поэтому canvas-загрузка в web не работает. html <img> в этом
        // случае обходит cors и показывается как platform view.
        ? _WebImage(
            url: url!,
            fit: fit,
            alignment: alignment,
            width: width,
            height: height,
          )
        : CachedNetworkImage(
            imageUrl: url!,
            fit: fit,
            alignment: alignment,
            width: width,
            height: height,
            memCacheWidth: memCacheWidth,
            fadeInDuration: const Duration(milliseconds: 260),
            fadeOutDuration: const Duration(milliseconds: 120),
            placeholder: (context, url) => const _ImagePlaceholder(),
            errorWidget: (context, url, error) => const _ImageFallback(),
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

class _WebImage extends StatelessWidget {
  const _WebImage({
    required this.url,
    required this.fit,
    required this.alignment,
    this.width,
    this.height,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        const _ImagePlaceholder(),
        Image.network(
          url,
          fit: fit,
          alignment: alignment,
          width: width,
          height: height,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (context, error, stackTrace) => const _ImageFallback(),
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceHigh,
            AppColors.surfaceSoft.withValues(alpha: 0.8),
            AppColors.surfaceHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceHigh, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.movie_filter_outlined,
          color: AppColors.textFaint,
          size: 28,
        ),
      ),
    );
  }
}
