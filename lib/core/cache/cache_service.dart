import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Immutable snapshot of the app's image cache usage.
class CacheStats {
  const CacheStats({
    required this.bytes,
    required this.count,
    required this.temporaryBytes,
    required this.temporaryCount,
  });

  static const empty = CacheStats(
    bytes: 0,
    count: 0,
    temporaryBytes: 0,
    temporaryCount: 0,
  );

  /// Total bytes kept by the disk cache and the in-memory image cache.
  final int bytes;

  /// Number of cached entries across both layers.
  final int count;

  /// Bytes currently kept as decoded images in RAM.
  final int temporaryBytes;

  /// Number of decoded images in RAM.
  final int temporaryCount;

  String get label => formatBytes(bytes);

  String get temporaryLabel => formatBytes(temporaryBytes);
}

/// Reads and clears the caches used for posters, stills and trailers.
class CacheService {
  const CacheService._();

  /// Collects the current cache size without blocking the UI for long.
  static Future<CacheStats> stats() async {
    var diskBytes = 0;
    var diskCount = 0;

    try {
      final manager = DefaultCacheManager();
      final repo = manager.config.repo;
      await repo.open();
      final objects = await repo.getAllObjects();
      for (final object in objects) {
        // `CacheObject.length` is only filled in on web; elsewhere read the
        // real file size so desktop and mobile report meaningful numbers.
        var length = object.length ?? 0;
        try {
          final file = await manager.config.fileSystem.createFile(
            object.relativePath,
          );
          if (await file.exists()) {
            final fileLength = await file.length();
            if (fileLength > 0) length = fileLength;
          }
        } catch (_) {
          // A missing/unsupported file falls back to stored metadata.
        }
        if (length > 0) {
          diskBytes += length;
          diskCount++;
        }
      }
      await repo.close();
    } catch (_) {
      // Cache metadata can be unavailable (web, first launch): report zero.
    }

    final imageCache = PaintingBinding.instance.imageCache;
    final memoryBytes = imageCache.currentSizeBytes;
    final memoryCount = imageCache.currentSize;

    return CacheStats(
      bytes: diskBytes + memoryBytes,
      count: diskCount + memoryCount,
      temporaryBytes: memoryBytes,
      temporaryCount: memoryCount,
    );
  }

  /// Removes downloaded files and decoded images from memory.
  static Future<void> clear() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {
      // Clearing an empty/unsupported cache is harmless.
    }
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }
}

/// Human readable byte size, e.g. `12,4 мб`.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 б';
  const units = ['б', 'кб', 'мб', 'гб'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || unit == 0 ? 0 : 1;
  final text = value.toStringAsFixed(digits).replaceAll('.', ',');
  return '$text ${units[unit]}';
}
