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
    this.fallbackLabel,
    this.canvasOnly = false,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final Alignment alignment;
  final int? memCacheWidth;
  final String? fallbackLabel;

  /// On web, force a canvas-decoded image instead of an HTML `<img>`.
  ///
  /// Use this for images that sit inside a tappable card: an HTML platform
  /// view would otherwise swallow the pointer event. Only use it for hosts
  /// that send CORS headers (for example YouTube thumbnails).
  final bool canvasOnly;

  @override
  Widget build(BuildContext context) {
    final image = url == null || url!.isEmpty
        ? _ImageFallback(label: fallbackLabel)
        : kIsWeb && !canvasOnly
        // постеры anilibria отдаются без access-control-allow-origin,
        // поэтому canvas-загрузка в web не работает. html <img> в этом
        // случае обходит cors и показывается как platform view.
        ? _WebImage(
            url: url!,
            fit: fit,
            alignment: alignment,
            width: width,
            height: height,
            fallbackLabel: fallbackLabel,
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
            errorWidget: (context, url, error) =>
                _ImageFallback(label: fallbackLabel),
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
    this.fallbackLabel,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final String? fallbackLabel;

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
          errorBuilder: (context, error, stackTrace) =>
              _ImageFallback(label: fallbackLabel),
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
  const _ImageFallback({this.label});

  final String? label;

  String? get _initial {
    final value = label?.trim();
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'[a-zа-я0-9]', caseSensitive: false).firstMatch(value);
    return match?.group(0)?.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _initial;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceHigh, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: initial == null
            ? const Icon(
                Icons.movie_filter_outlined,
                color: AppColors.textFaint,
                size: 28,
              )
            : Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'Unbounded',
                  fontWeight: FontWeight.w700,
                  fontSize: 30,
                  color: AppColors.textFaint,
                ),
              ),
      ),
    );
  }
}
