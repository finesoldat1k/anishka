/// Shikimori API configuration.
abstract final class ShikimoriConfig {
  static const host = 'https://shikimori.io';
  static const apiBase = '$host/api';
  static const imageBase = host;

  static String? imageUrl(String? path) {
    if (path == null) return null;
    final value = path.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';
    return value.startsWith('/') ? '$imageBase$value' : '$imageBase/$value';
  }
}
