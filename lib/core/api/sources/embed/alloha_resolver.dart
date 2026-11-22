import '../resolved_stream.dart';
import 'embed_resolver.dart';

/// Alloha player fallback.
///
/// Alloha signs playback requests from JavaScript and requires `borth` /
/// `Authorizations` headers generated at runtime. There is no stable pure-Dart
/// extraction path, so this resolver only claims the URL; the player keeps the
/// embed as its fallback on platforms that support WebViews.
class AllohaResolver implements EmbedResolver {
  @override
  String get id => 'alloha';

  @override
  bool canResolve(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('alloha');
  }

  @override
  Future<ResolvedStream?> resolve(
    String url, {
    String quality = 'auto',
  }) async {
    return null;
  }
}
