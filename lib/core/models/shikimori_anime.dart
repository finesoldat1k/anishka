// Shikimori anime models for catalog/search.
import '../../core/api/shikimori_config.dart';
import '../../core/utils/format.dart';

/// Compact anime entry for lists (search, home, etc.).
class ShikimoriAnime {
  const ShikimoriAnime({
    required this.id,
    required this.name,
    required this.russian,
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.image,
    required this.url,
    this.airedOn,
    this.releasedOn,
  });

  final int id;
  final String name;
  final String russian;
  final String kind; // tv, movie, ova, ona, special, music
  final String score;
  final String status; // released, ongoing, anons, etc.
  final int episodes;
  final int episodesAired;
  final ShikimoriImage image;
  final String url; // /animes/16498-shingeki-no-kyojin
  final String? airedOn;
  final String? releasedOn;

  factory ShikimoriAnime.fromJson(Map<String, dynamic> json) {
    return ShikimoriAnime(
      id: json['id'] as int,
      name: (json['name'] as String? ?? '').lc,
      russian: (json['russian'] as String? ?? '').lc,
      kind: (json['kind'] as String? ?? '').lc,
      score: (json['score'] as String? ?? '').lc,
      status: (json['status'] as String? ?? '').lc,
      episodes: json['episodes'] as int? ?? 0,
      episodesAired: json['episodes_aired'] as int? ?? 0,
      image: ShikimoriImage.fromJson(
        json['image'] as Map<String, dynamic>? ?? {},
      ),
      url: (json['url'] as String? ?? '').lc,
      airedOn: json['aired_on'] as String?,
      releasedOn: json['released_on'] as String?,
    );
  }

  /// Display title (russian preferred).
  String get displayTitle => russian.isNotEmpty ? russian : name;

  /// Poster URL for lists (preview size, with graceful fallbacks).
  String? get posterUrl =>
      _bestImage([image.preview, image.x96, image.original, image.x48]);

  /// Poster URL for details (original size, with graceful fallbacks).
  String? get posterOriginalUrl =>
      _bestImage([image.original, image.preview, image.x96, image.x48]);

  /// Background/fanart URL.
  String? get backgroundUrl =>
      _bestImage([image.original, image.preview, image.x96]);

  String? _bestImage(List<String?> candidates) {
    for (final candidate in candidates) {
      final url = ShikimoriConfig.imageUrl(candidate);
      if (!_isMissingPlaceholder(url)) return url;
    }
    return null;
  }

  bool _isMissingPlaceholder(String? url) {
    if (url == null) return true;
    return url.contains('/assets/globals/missing_');
  }

  /// Year from aired_on.
  int? get year {
    if (airedOn == null) return null;
    return int.tryParse(airedOn!.substring(0, 4));
  }

  /// Status label for UI.
  String get statusLabel => switch (status) {
    'ongoing' => 'выходит',
    'released' => 'вышло',
    'anons' => 'анонс',
    _ => status,
  };

  /// Kind label for UI.
  String get kindLabel => switch (kind) {
    'tv' => 'tv',
    'movie' => 'фильм',
    'ova' => 'ова',
    'ona' => 'она',
    'special' => 'спешл',
    'music' => 'клип',
    _ => kind,
  };

  /// Lightweight details object used for instant first paint on the details
  /// page while the full Shikimori response is in flight.
  ShikimoriAnimeDetails toDetailsPreview() {
    return ShikimoriAnimeDetails(
      id: id,
      name: name,
      russian: russian,
      kind: kind,
      score: score,
      status: status,
      episodes: episodes,
      episodesAired: episodesAired,
      image: image,
      url: url,
      airedOn: airedOn,
      releasedOn: releasedOn,
    );
  }
}

/// Image sizes from Shikimori.
class ShikimoriImage {
  const ShikimoriImage({this.original, this.preview, this.x96, this.x48});

  final String? original;
  final String? preview;
  final String? x96;
  final String? x48;

  factory ShikimoriImage.fromJson(Map<String, dynamic> json) {
    return ShikimoriImage(
      original: json['original'] as String?,
      preview: json['preview'] as String?,
      x96: json['x96'] as String?,
      x48: json['x48'] as String?,
    );
  }
}

/// Detailed anime from Shikimori (for details screen).
class ShikimoriAnimeDetails {
  const ShikimoriAnimeDetails({
    required this.id,
    required this.name,
    required this.russian,
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.image,
    required this.url,
    this.airedOn,
    this.releasedOn,
    this.duration,
    this.description,
    this.descriptionHtml,
    this.rating,
    this.english,
    this.japanese,
    this.synonyms,
    this.genres,
    this.studios,
    this.videos,
    this.anilibriaPosterFallback,
    this.anilibriaBackgroundFallback,
    this.franchise,
    this.trailerUrl,
    this.trailerThumbnail,
    this.trailerSite,
    this.screenshots = const [],
    this.metadataPoster,
    this.metadataBackground,
    this.metadataScore,
    this.metadataYear,
    this.metadataEpisodes,
    this.metadataDuration,
    this.metadataDescription,
    this.metadataEnglishTitle,
    this.metadataGenres = const [],
    this.metadataStudios = const [],
  });

  final int id;
  final String name;
  final String russian;
  final String kind;
  final String score;
  final String status;
  final int episodes;
  final int episodesAired;
  final ShikimoriImage image;
  final String url;
  final String? airedOn;
  final String? releasedOn;
  final int? duration;
  final String? description;
  final String? descriptionHtml;
  final String? rating; // r, r17, etc.
  final List<String>? english;
  final List<String>? japanese;
  final List<String>? synonyms;
  final List<ShikimoriGenre>? genres;
  final List<ShikimoriStudio>? studios;
  final List<ShikimoriVideo>? videos;

  /// AniLibria poster fallback when Shikimori image is missing.
  final String? anilibriaPosterFallback;

  /// AniLibria background fallback when Shikimori image is missing.
  final String? anilibriaBackgroundFallback;

  /// Shikimori franchise identifier (e.g., "fullmetal_alchemist").
  final String? franchise;

  /// Trailer URL (YouTube/Dailymotion watch link).
  final String? trailerUrl;

  /// Trailer thumbnail (YouTube preview or AniList image).
  final String? trailerThumbnail;

  /// Trailer hosting: youtube, dailymotion, etc.
  final String? trailerSite;

  /// Episode stills (Shikimori screenshots), full URLs.
  final List<String> screenshots;

  /// Fallback metadata merged from AniList/Kitsu when Shikimori is sparse.
  final String? metadataPoster;
  final String? metadataBackground;
  final double? metadataScore;
  final int? metadataYear;
  final int? metadataEpisodes;
  final int? metadataDuration;
  final String? metadataDescription;
  final String? metadataEnglishTitle;
  final List<String> metadataGenres;
  final List<String> metadataStudios;

  factory ShikimoriAnimeDetails.fromJson(Map<String, dynamic> json) {
    return ShikimoriAnimeDetails(
      id: json['id'] as int,
      name: (json['name'] as String? ?? '').lc,
      russian: (json['russian'] as String? ?? '').lc,
      kind: (json['kind'] as String? ?? '').lc,
      score: (json['score'] as String? ?? '').lc,
      status: (json['status'] as String? ?? '').lc,
      episodes: json['episodes'] as int? ?? 0,
      episodesAired: json['episodes_aired'] as int? ?? 0,
      image: ShikimoriImage.fromJson(
        json['image'] as Map<String, dynamic>? ?? {},
      ),
      url: (json['url'] as String? ?? '').lc,
      airedOn: json['aired_on'] as String?,
      releasedOn: json['released_on'] as String?,
      duration: json['duration'] as int?,
      description: (json['description'] as String? ?? '').lc,
      descriptionHtml: json['description_html'] as String?,
      rating: json['rating'] as String?,
      english: (json['english'] as List?)?.cast<String>(),
      japanese: (json['japanese'] as List?)?.cast<String>(),
      synonyms: (json['synonyms'] as List?)?.cast<String>(),
      genres: (json['genres'] as List?)
          ?.map((g) => ShikimoriGenre.fromJson(g as Map<String, dynamic>))
          .toList(),
      studios: (json['studios'] as List?)
          ?.map((s) => ShikimoriStudio.fromJson(s as Map<String, dynamic>))
          .toList(),
      videos: (json['videos'] as List?)
          ?.map((v) => ShikimoriVideo.fromJson(v as Map<String, dynamic>))
          .toList(),
      franchise: json['franchise'] as String?,
      screenshots:
          (json['screenshots'] as List?)
              ?.map(
                (e) => e is Map<String, dynamic>
                    ? ShikimoriConfig.imageUrl(e['original'] as String?)
                    : null,
              )
              .whereType<String>()
              .toList() ??
          const [],
    );
  }

  String get displayTitle => russian.isNotEmpty ? russian : name;

  String? get posterUrl =>
      _bestImage([image.preview, image.x96, image.original, image.x48]) ??
      anilibriaPosterFallback ??
      metadataPoster;

  String? get posterOriginalUrl =>
      _bestImage([image.original, image.preview, image.x96, image.x48]) ??
      anilibriaPosterFallback ??
      metadataPoster;

  String? get backgroundUrl =>
      _bestImage([image.original, image.preview, image.x96]) ??
      anilibriaBackgroundFallback ??
      metadataBackground;

  String? _bestImage(List<String?> candidates) {
    for (final candidate in candidates) {
      final url = ShikimoriConfig.imageUrl(candidate);
      if (!_isMissingPlaceholder(url)) return url;
    }
    return null;
  }

  bool _isMissingPlaceholder(String? url) {
    if (url == null) return true;
    return url.contains('/assets/globals/missing_');
  }

  int? get year {
    if (airedOn != null && airedOn!.length >= 4) {
      final parsed = int.tryParse(airedOn!.substring(0, 4));
      if (parsed != null && parsed > 0) return parsed;
    }
    return metadataYear;
  }

  /// Score from Shikimori, falling back to AniList/Kitsu.
  double? get scoreValue {
    final parsed = double.tryParse(score);
    if (parsed != null && parsed > 0) return parsed;
    return metadataScore;
  }

  /// Full description, falling back to AniList/Kitsu when Shikimori has none.
  String get descriptionText {
    final value = description?.trim() ?? '';
    if (value.isNotEmpty && !value.startsWith('нет описания')) return value;
    return metadataDescription?.trim() ?? '';
  }

  /// English title, merged from all metadata providers.
  String? get englishTitle {
    if (english != null && english!.isNotEmpty) return english!.first;
    final fallback = metadataEnglishTitle?.trim();
    return fallback == null || fallback.isEmpty ? null : fallback;
  }

  /// All genre labels (Russian from Shikimori, otherwise AniList/Kitsu).
  List<String> get allGenres {
    final shikimoriGenres =
        genres
            ?.map((g) => g.russian.isNotEmpty ? g.russian : g.name)
            .where((value) => value.isNotEmpty)
            .toList() ??
        const <String>[];
    if (shikimoriGenres.isNotEmpty) {
      return _uniqueCaseInsensitive(shikimoriGenres);
    }
    return _uniqueCaseInsensitive(metadataGenres);
  }

  /// All studio names (Shikimori first, AniList/Kitsu as a fallback).
  List<String> get allStudios {
    final values = <String>[
      ...?studios?.map((s) => s.name).where((value) => value.isNotEmpty),
      ...metadataStudios.where((value) => value.isNotEmpty),
    ];
    return _uniqueCaseInsensitive(values);
  }

  int? get durationMinutes => duration ?? metadataDuration;

  /// Parsed YouTube id from [trailerUrl], falling back to Shikimori videos.
  ///
  /// The base Shikimori response already contains `videos`, so the ambient
  /// trailer can start before the AniList/Kitsu enrichment finishes.
  String? get trailerYoutubeId {
    final direct = _youtubeIdFromUrl(trailerUrl);
    if (direct != null) return direct;
    for (final video in videos ?? const <ShikimoriVideo>[]) {
      if (video.kind != 'pv' && video.kind != 'op') continue;
      final id = _youtubeIdFromUrl(video.url);
      if (id != null) return id;
    }
    return null;
  }

  String? _youtubeIdFromUrl(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host.contains('youtu.be')) {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    if (host.contains('youtube.com') || host.contains('youtube-nocookie.com')) {
      final queryId = uri.queryParameters['v'];
      if (queryId != null && queryId.isNotEmpty) return queryId;
      final segments = uri.pathSegments;
      if (segments.length >= 2 &&
          (segments.first == 'embed' || segments.first == 'shorts')) {
        return segments[1];
      }
    }
    return null;
  }

  /// Best available still for compact visuals.
  String? get stillUrl {
    if (screenshots.isNotEmpty) return screenshots.first;
    return trailerThumbnail ?? backgroundUrl ?? posterOriginalUrl;
  }

  String get statusLabel => switch (status) {
    'ongoing' => 'выходит',
    'released' => 'вышло',
    'anons' => 'анонс',
    _ => status,
  };

  String get kindLabel => switch (kind) {
    'tv' => 'tv',
    'movie' => 'фильм',
    'ova' => 'ова',
    'ona' => 'она',
    'special' => 'спешл',
    'music' => 'клип',
    _ => kind,
  };

  String get genresLabel => genres?.map((g) => g.russian).join(', ') ?? '';

  int get episodeCount =>
      episodes > 0 ? episodes : (episodesAired > 0 ? episodesAired : 0);

  bool get isOngoing => status == 'ongoing';

  static ShikimoriAnimeDetails empty() => const ShikimoriAnimeDetails(
    id: 0,
    name: '',
    russian: '',
    kind: '',
    score: '',
    status: '',
    episodes: 0,
    episodesAired: 0,
    image: ShikimoriImage(original: null, preview: null, x96: null, x48: null),
    url: '',
    airedOn: null,
    releasedOn: null,
    duration: null,
    description: null,
    descriptionHtml: null,
    rating: null,
    english: null,
    japanese: null,
    synonyms: null,
    genres: null,
    studios: null,
    videos: null,
    anilibriaPosterFallback: null,
    anilibriaBackgroundFallback: null,
    franchise: null,
    trailerUrl: null,
    trailerThumbnail: null,
    trailerSite: null,
    screenshots: [],
    metadataPoster: null,
    metadataBackground: null,
    metadataScore: null,
    metadataYear: null,
    metadataEpisodes: null,
    metadataDuration: null,
    metadataDescription: null,
    metadataEnglishTitle: null,
    metadataGenres: [],
    metadataStudios: [],
  );

  ShikimoriAnimeDetails copyWith({
    int? id,
    String? name,
    String? russian,
    String? kind,
    String? score,
    String? status,
    int? episodes,
    int? episodesAired,
    ShikimoriImage? image,
    String? url,
    String? airedOn,
    String? releasedOn,
    int? duration,
    String? description,
    String? descriptionHtml,
    String? rating,
    List<String>? english,
    List<String>? japanese,
    List<String>? synonyms,
    List<ShikimoriGenre>? genres,
    List<ShikimoriStudio>? studios,
    List<ShikimoriVideo>? videos,
    String? anilibriaPosterFallback,
    String? anilibriaBackgroundFallback,
    String? franchise,
    String? trailerUrl,
    String? trailerThumbnail,
    String? trailerSite,
    List<String>? screenshots,
    String? metadataPoster,
    String? metadataBackground,
    double? metadataScore,
    int? metadataYear,
    int? metadataEpisodes,
    int? metadataDuration,
    String? metadataDescription,
    String? metadataEnglishTitle,
    List<String>? metadataGenres,
    List<String>? metadataStudios,
  }) {
    return ShikimoriAnimeDetails(
      id: id ?? this.id,
      name: name ?? this.name,
      russian: russian ?? this.russian,
      kind: kind ?? this.kind,
      score: score ?? this.score,
      status: status ?? this.status,
      episodes: episodes ?? this.episodes,
      episodesAired: episodesAired ?? this.episodesAired,
      image: image ?? this.image,
      url: url ?? this.url,
      airedOn: airedOn ?? this.airedOn,
      releasedOn: releasedOn ?? this.releasedOn,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      descriptionHtml: descriptionHtml ?? this.descriptionHtml,
      rating: rating ?? this.rating,
      english: english ?? this.english,
      japanese: japanese ?? this.japanese,
      synonyms: synonyms ?? this.synonyms,
      genres: genres ?? this.genres,
      studios: studios ?? this.studios,
      videos: videos ?? this.videos,
      anilibriaPosterFallback:
          anilibriaPosterFallback ?? this.anilibriaPosterFallback,
      anilibriaBackgroundFallback:
          anilibriaBackgroundFallback ?? this.anilibriaBackgroundFallback,
      franchise: franchise ?? this.franchise,
      trailerUrl: trailerUrl ?? this.trailerUrl,
      trailerThumbnail: trailerThumbnail ?? this.trailerThumbnail,
      trailerSite: trailerSite ?? this.trailerSite,
      screenshots: screenshots ?? this.screenshots,
      metadataPoster: metadataPoster ?? this.metadataPoster,
      metadataBackground: metadataBackground ?? this.metadataBackground,
      metadataScore: metadataScore ?? this.metadataScore,
      metadataYear: metadataYear ?? this.metadataYear,
      metadataEpisodes: metadataEpisodes ?? this.metadataEpisodes,
      metadataDuration: metadataDuration ?? this.metadataDuration,
      metadataDescription: metadataDescription ?? this.metadataDescription,
      metadataEnglishTitle: metadataEnglishTitle ?? this.metadataEnglishTitle,
      metadataGenres: metadataGenres ?? this.metadataGenres,
      metadataStudios: metadataStudios ?? this.metadataStudios,
    );
  }
}

class ShikimoriGenre {
  const ShikimoriGenre({
    required this.id,
    required this.name,
    required this.russian,
    this.kind,
  });
  final int id;
  final String name;
  final String russian;
  final String? kind;

  factory ShikimoriGenre.fromJson(Map<String, dynamic> json) {
    return ShikimoriGenre(
      id: json['id'] as int,
      name: (json['name'] as String? ?? '').lc,
      russian: (json['russian'] as String? ?? '').lc,
      kind: json['kind'] as String?,
    );
  }
}

class ShikimoriStudio {
  const ShikimoriStudio({
    required this.id,
    required this.name,
    this.filteredName,
  });
  final int id;
  final String name;
  final String? filteredName;

  factory ShikimoriStudio.fromJson(Map<String, dynamic> json) {
    return ShikimoriStudio(
      id: json['id'] as int,
      name: (json['name'] as String? ?? '').lc,
      filteredName: json['filtered_name'] as String?,
    );
  }
}

class ShikimoriVideo {
  const ShikimoriVideo({
    required this.id,
    required this.url,
    required this.name,
    required this.kind,
    required this.hosting,
  });
  final int id;
  final String url;
  final String name;
  final String kind; // pv, cm, etc.
  final String hosting; // youtube

  factory ShikimoriVideo.fromJson(Map<String, dynamic> json) {
    return ShikimoriVideo(
      id: json['id'] as int,
      url: json['url'] as String? ?? '',
      name: (json['name'] as String? ?? '').lc,
      kind: (json['kind'] as String? ?? '').lc,
      hosting: (json['hosting'] as String? ?? '').lc,
    );
  }
}

/// Deduplicates labels while ignoring case, preserving the first spelling.
List<String> _uniqueCaseInsensitive(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    if (seen.add(value.toLowerCase())) result.add(value);
  }
  return result;
}
