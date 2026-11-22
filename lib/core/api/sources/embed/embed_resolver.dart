import '../resolved_stream.dart';

/// Resolves a provider embed/player URL into a direct stream.
///
/// Implementations are stateless apart from small in-memory caches. They are
/// safe to call from multiple sources concurrently.
abstract interface class EmbedResolver {
  /// Stable identifier, also used as `resolverSource` on episodes.
  String get id;

  /// Whether this resolver understands [url].
  bool canResolve(String url);

  /// Resolve [url] to a direct stream.
  ///
  /// Returns `null` when the player is unsupported, blocked, or the extraction
  /// failed. Implementations must never throw for expected network errors.
  Future<ResolvedStream?> resolve(String url, {String quality = 'auto'});
}

/// Ordered registry of embed resolvers.
class EmbedResolverRegistry {
  EmbedResolverRegistry([Iterable<EmbedResolver> resolvers = const []]) {
    for (final resolver in resolvers) {
      register(resolver);
    }
  }

  final List<EmbedResolver> _resolvers = [];

  List<EmbedResolver> get all => List.unmodifiable(_resolvers);

  void register(EmbedResolver resolver) {
    _resolvers.removeWhere((item) => item.id == resolver.id);
    _resolvers.add(resolver);
  }

  EmbedResolver? byId(String id) {
    for (final resolver in _resolvers) {
      if (resolver.id == id) return resolver;
    }
    return null;
  }

  /// Find the resolver responsible for [url].
  EmbedResolver? findFor(String url) {
    final value = url.trim();
    if (value.isEmpty) return null;
    for (final resolver in _resolvers) {
      if (resolver.canResolve(value)) return resolver;
    }
    return null;
  }

  bool canResolve(String url) => findFor(url) != null;

  /// Resolve [url] with the first matching resolver.
  Future<ResolvedStream?> resolve(
    String url, {
    String quality = 'auto',
  }) async {
    final resolver = findFor(url);
    if (resolver == null) return null;
    try {
      return await resolver.resolve(url, quality: quality);
    } catch (_) {
      return null;
    }
  }

  /// Resolve using a known resolver id, falling back to URL matching.
  Future<ResolvedStream?> resolveWith(
    String? resolverId,
    String url, {
    String quality = 'auto',
  }) async {
    final resolver = (resolverId == null ? null : byId(resolverId)) ?? findFor(url);
    if (resolver == null) return null;
    try {
      return await resolver.resolve(url, quality: quality);
    } catch (_) {
      return null;
    }
  }
}
