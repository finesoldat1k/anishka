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
      image: ShikimoriImage.fromJson(json['image'] as Map<String, dynamic>? ?? {}),
      url: (json['url'] as String? ?? '').lc,
      airedOn: json['aired_on'] as String?,
      releasedOn: json['released_on'] as String?,
    );
  }

  /// Display title (russian preferred).
  String get displayTitle => russian.isNotEmpty ? russian : name;

  /// Poster URL for lists (preview size).
  String? get posterUrl {
    final url = ShikimoriConfig.imageUrl(image.preview);
    return _isMissingPlaceholder(url) ? null : url;
  }

  /// Poster URL for details (original size).
  String? get posterOriginalUrl {
    final url = ShikimoriConfig.imageUrl(image.original);
    return _isMissingPlaceholder(url) ? null : url;
  }

  /// Background/fanart URL.
  String? get backgroundUrl {
    final url = ShikimoriConfig.imageUrl(image.original);
    return _isMissingPlaceholder(url) ? null : url;
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
}

/// Image sizes from Shikimori.
class ShikimoriImage {
  const ShikimoriImage({
    this.original,
    this.preview,
    this.x96,
    this.x48,
  });

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
      image: ShikimoriImage.fromJson(json['image'] as Map<String, dynamic>? ?? {}),
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
    );
  }

  String get displayTitle => russian.isNotEmpty ? russian : name;

  String? get posterUrl {
    final url = ShikimoriConfig.imageUrl(image.preview);
    final shikimoriUrl = _isMissingPlaceholder(url) ? null : url;
    return shikimoriUrl ?? anilibriaPosterFallback;
  }

  String? get posterOriginalUrl {
    final url = ShikimoriConfig.imageUrl(image.original);
    final shikimoriUrl = _isMissingPlaceholder(url) ? null : url;
    return shikimoriUrl ?? anilibriaPosterFallback;
  }

  String? get backgroundUrl {
    final url = ShikimoriConfig.imageUrl(image.original);
    final shikimoriUrl = _isMissingPlaceholder(url) ? null : url;
    return shikimoriUrl ?? anilibriaBackgroundFallback;
  }

  bool _isMissingPlaceholder(String? url) {
    if (url == null) return true;
    return url.contains('/assets/globals/missing_');
  }

  int? get year {
    if (airedOn == null) return null;
    return int.tryParse(airedOn!.substring(0, 4));
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

  int get episodeCount => episodes > 0 ? episodes : (episodesAired > 0 ? episodesAired : 0);

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
      anilibriaPosterFallback: anilibriaPosterFallback ?? this.anilibriaPosterFallback,
      anilibriaBackgroundFallback: anilibriaBackgroundFallback ?? this.anilibriaBackgroundFallback,
      franchise: franchise ?? this.franchise,
    );
  }
}

class ShikimoriGenre {
  const ShikimoriGenre({required this.id, required this.name, required this.russian, this.kind});
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
  const ShikimoriStudio({required this.id, required this.name, this.filteredName});
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