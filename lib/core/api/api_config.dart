abstract final class ApiConfig {
  static const host = 'https://anilibria.top';
  static const apiBase = '$host/api/v1';

  static String? mediaUrl(String? path) {
    if (path == null) return null;
    final value = path.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';
    return value.startsWith('/') ? '$host$value' : '$host/$value';
  }
}
