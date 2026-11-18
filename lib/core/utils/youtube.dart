/// Утилиты для youtube-ссылок shikimori.
library;

/// Извлекает идентификатор видео из watch/short/embed-ссылки.
String? youtubeVideoId(String url) {
  if (url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  if (uri.host.contains('youtu.be')) {
    return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  }
  if (uri.host.contains('youtube.com') || uri.host.contains('youtube-nocookie.com')) {
    final fromQuery = uri.queryParameters['v'];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'embed') return segments[1];
  }
  return null;
}
