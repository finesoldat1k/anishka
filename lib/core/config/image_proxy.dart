// Image proxy configuration for CORS-blocked images.
import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuration for image proxy services.
class ImageProxyConfig {
  ImageProxyConfig._();

  /// Enable/disable image proxy globally.
  static bool enabled = true;

  /// Preferred proxy service (auto-selects if null).
  static ImageProxyService? preferredProxy;

  /// Available proxy services in priority order.
  static final List<ImageProxyService> proxies = [
    ImageProxyService(
      id: 'images.weserv.nl',
      name: 'images.weserv.nl',
      buildUrl: (url) => 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}',
      supportsHttps: true,
      notes: 'Fast, free, supports most hosts',
    ),
    ImageProxyService(
      id: 'r.jina.ai',
      name: 'r.jina.ai/http',
      buildUrl: (url) => 'https://r.jina.ai/http://${Uri.encodeComponent(url)}',
      supportsHttps: true,
      notes: 'Jina AI reader proxy',
    ),
    ImageProxyService(
      id: 'cors.isteed.cc',
      name: 'cors.isteed.cc',
      buildUrl: (url) => 'https://cors.isteed.cc/$url',
      supportsHttps: true,
      notes: 'Generic CORS proxy',
    ),
    ImageProxyService(
      id: 'api.allorigins.win',
      name: 'allorigins.win',
      buildUrl: (url) => 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}',
      supportsHttps: true,
      notes: 'AllOrigins CORS proxy',
    ),
  ];

  /// Get the best available proxy for a URL.
  static ImageProxyService? getProxyFor(String url) {
    if (!enabled) return null;
    if (preferredProxy != null) return preferredProxy;

    // For Shikimori images, images.weserv.nl works well
    if (url.contains('shikimori.io')) {
      return proxies.firstWhere((p) => p.id == 'images.weserv.nl');
    }

    // For other CORS-blocked hosts, try the first working proxy
    return proxies.first;
  }

  /// Build proxied URL for an image.
  static String? buildProxiedUrl(String url) {
    final proxy = getProxyFor(url);
    if (proxy == null) return url;
    return proxy.buildUrl(url);
  }
}

/// Represents an image proxy service.
class ImageProxyService {
  const ImageProxyService({
    required this.id,
    required this.name,
    required this.buildUrl,
    required this.supportsHttps,
    required this.notes,
  });

  final String id;
  final String name;
  final String Function(String url) buildUrl;
  final bool supportsHttps;
  final String notes;
}