/// Jikan API models for MyAnimeList data.
library;

/// Compact anime entry from Jikan search.
class JikanAnime {
  const JikanAnime({
    required this.malId,
    required this.url,
    required this.title,
    this.titleEnglish,
    this.titleJapanese,
    this.titleSynonyms = const [],
    this.type,
    this.source,
    this.episodes,
    this.status,
    this.airing,
    this.aired,
    this.duration,
    this.rating,
    this.score,
    this.scoredBy,
    this.rank,
    this.popularity,
    this.members,
    this.favorites,
    this.synopsis,
    this.background,
    this.season,
    this.year,
    this.broadcast,
    this.producers = const [],
    this.licensors = const [],
    this.studios = const [],
    this.genres = const [],
    this.explicitGenres = const [],
    this.themes = const [],
    this.demographics = const [],
    this.images,
    this.trailer,
  });

  final int malId;
  final String url;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final List<String> titleSynonyms;
  final String? type;
  final String? source;
  final int? episodes;
  final String? status;
  final bool? airing;
  final JikanAired? aired;
  final String? duration;
  final String? rating;
  final double? score;
  final int? scoredBy;
  final int? rank;
  final int? popularity;
  final int? members;
  final int? favorites;
  final String? synopsis;
  final String? background;
  final String? season;
  final int? year;
  final JikanBroadcast? broadcast;
  final List<JikanProducer> producers;
  final List<JikanProducer> licensors;
  final List<JikanProducer> studios;
  final List<JikanGenre> genres;
  final List<JikanGenre> explicitGenres;
  final List<JikanGenre> themes;
  final List<JikanGenre> demographics;
  final JikanImages? images;
  final JikanTrailer? trailer;

  factory JikanAnime.fromJson(Map<String, dynamic> json) {
    return JikanAnime(
      malId: json['mal_id'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      titleEnglish: json['title_english'] as String?,
      titleJapanese: json['title_japanese'] as String?,
      titleSynonyms:
          (json['title_synonyms'] as List?)?.map((e) => e as String).toList() ??
          const [],
      type: json['type'] as String?,
      source: json['source'] as String?,
      episodes: json['episodes'] as int?,
      status: json['status'] as String?,
      airing: json['airing'] as bool?,
      aired: json['aired'] != null
          ? JikanAired.fromJson(json['aired'] as Map<String, dynamic>)
          : null,
      duration: json['duration'] as String?,
      rating: json['rating'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      scoredBy: json['scored_by'] as int?,
      rank: json['rank'] as int?,
      popularity: json['popularity'] as int?,
      members: json['members'] as int?,
      favorites: json['favorites'] as int?,
      synopsis: json['synopsis'] as String?,
      background: json['background'] as String?,
      season: json['season'] as String?,
      year: json['year'] as int?,
      broadcast: json['broadcast'] != null
          ? JikanBroadcast.fromJson(json['broadcast'] as Map<String, dynamic>)
          : null,
      producers:
          (json['producers'] as List?)
              ?.map((e) => JikanProducer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      licensors:
          (json['licensors'] as List?)
              ?.map((e) => JikanProducer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      studios:
          (json['studios'] as List?)
              ?.map((e) => JikanProducer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      genres:
          (json['genres'] as List?)
              ?.map((e) => JikanGenre.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      explicitGenres:
          (json['explicit_genres'] as List?)
              ?.map((e) => JikanGenre.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      themes:
          (json['themes'] as List?)
              ?.map((e) => JikanGenre.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      demographics:
          (json['demographics'] as List?)
              ?.map((e) => JikanGenre.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      images: json['images'] != null
          ? JikanImages.fromJson(json['images'] as Map<String, dynamic>)
          : null,
      trailer: json['trailer'] != null
          ? JikanTrailer.fromJson(json['trailer'] as Map<String, dynamic>)
          : null,
    );
  }

  String get bestTitle =>
      titleEnglish?.isNotEmpty == true ? titleEnglish! : title;

  String? get posterUrl => images?.jpg?.largeImageUrl ?? images?.jpg?.imageUrl;

  String? get backgroundUrl =>
      images?.jpg?.largeImageUrl ?? images?.jpg?.imageUrl;
}

/// Full anime details from Jikan.
class JikanAnimeDetails {
  const JikanAnimeDetails({
    required this.malId,
    required this.url,
    required this.title,
    this.titleEnglish,
    this.titleJapanese,
    this.titleSynonyms = const [],
    this.type,
    this.source,
    this.episodes,
    this.status,
    this.airing,
    this.aired,
    this.duration,
    this.rating,
    this.score,
    this.scoredBy,
    this.rank,
    this.popularity,
    this.members,
    this.favorites,
    this.synopsis,
    this.background,
    this.season,
    this.year,
    this.broadcast,
    this.producers = const [],
    this.licensors = const [],
    this.studios = const [],
    this.genres = const [],
    this.explicitGenres = const [],
    this.themes = const [],
    this.demographics = const [],
    this.images,
    this.trailer,
    this.relations = const [],
    this.theme = const JikanTheme(),
    this.external = const [],
    this.streaming = const [],
  });

  final int malId;
  final String url;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final List<String> titleSynonyms;
  final String? type;
  final String? source;
  final int? episodes;
  final String? status;
  final bool? airing;
  final JikanAired? aired;
  final String? duration;
  final String? rating;
  final double? score;
  final int? scoredBy;
  final int? rank;
  final int? popularity;
  final int? members;
  final int? favorites;
  final String? synopsis;
  final String? background;
  final String? season;
  final int? year;
  final JikanBroadcast? broadcast;
  final List<JikanProducer> producers;
  final List<JikanProducer> licensors;
  final List<JikanProducer> studios;
  final List<JikanGenre> genres;
  final List<JikanGenre> explicitGenres;
  final List<JikanGenre> themes;
  final List<JikanGenre> demographics;
  final JikanImages? images;
  final JikanTrailer? trailer;
  final List<JikanRelation> relations;
  final JikanTheme theme;
  final List<JikanExternal> external;
  final List<JikanStreaming> streaming;

  factory JikanAnimeDetails.fromJson(Map<String, dynamic> json) {
    return JikanAnimeDetails(
      malId: json['mal_id'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      titleEnglish: json['title_english'] as String?,
      titleJapanese: json['title_japanese'] as String?,
      titleSynonyms:
          (json['title_synonyms'] as List?)?.map((e) => e as String).toList() ??
          const [],
      type: json['type'] as String?,
      source: json['source'] as String?,
      episodes: json['episodes'] as int?,
      status: json['status'] as String?,
      airing: json['airing'] as bool?,
      aired: json['aired'] != null
          ? JikanAired.fromJson(json['aired'] as Map<String, dynamic>)
          : null,
      duration: json['duration'] as String?,
      rating: json['rating'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      scoredBy: json['scored_by'] as int?,
      rank: json['rank'] as int?,
      popularity: json['popularity'] as int?,
      members: json['members'] as int?,
      favorites: json['favorites'] as int?,
      synopsis: json['synopsis'] as String?,
      background: json['background'] as String?,
      season: json['season'] as String?,
      year: json['year'] as int?,
      broadcast: json['broadcast'] != null
          ? JikanBroadcast.fromJson(json['broadcast'] as Map<String, dynamic>)
          : null,
      producers:
          (json['producers'] as List?)
              ?.map((e) => JikanProducer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      licensors:
          (json['licensors'] as List?)
              ?.map((e) => JikanProducer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      studios:
          (json['studios'] as List?)
              ?.map((e) => JikanProducer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      genres:
          (json['genres'] as List?)
              ?.map((e) => JikanGenre.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      explicitGenres:
          (json['explicit_genres'] as List?)
              ?.map((e) => JikanGenre.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      themes:
          (json['themes'] as List?)
              ?.map((e) => JikanGenre.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      demographics:
          (json['demographics'] as List?)
              ?.map((e) => JikanGenre.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      images: json['images'] != null
          ? JikanImages.fromJson(json['images'] as Map<String, dynamic>)
          : null,
      trailer: json['trailer'] != null
          ? JikanTrailer.fromJson(json['trailer'] as Map<String, dynamic>)
          : null,
      relations:
          (json['relations'] as List?)
              ?.map((e) => JikanRelation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      theme: json['theme'] != null
          ? JikanTheme.fromJson(json['theme'] as Map<String, dynamic>)
          : const JikanTheme(),
      external:
          (json['external'] as List?)
              ?.map((e) => JikanExternal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      streaming:
          (json['streaming'] as List?)
              ?.map((e) => JikanStreaming.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  List<String> get allGenres {
    final all = <String>[
      ...genres.map((g) => g.name),
      ...themes.map((g) => g.name),
      ...demographics.map((g) => g.name),
    ];
    return _unique(all);
  }

  List<String> get allStudios {
    final all = studios.map((s) => s.name).toList();
    return _unique(all);
  }

  String? get posterUrl => images?.jpg?.largeImageUrl ?? images?.jpg?.imageUrl;

  String? get backgroundUrl =>
      images?.jpg?.largeImageUrl ?? images?.jpg?.imageUrl;

  String? get trailerYoutubeId {
    final url = trailer?.url;
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    return uri.queryParameters['v'];
  }

  int? get episodeCount => episodes;

  bool get isOngoing => airing == true || status == 'Currently Airing';

  List<String> _unique(List<String> input) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in input) {
      final lower = item.toLowerCase();
      if (seen.add(lower)) result.add(item);
    }
    return result;
  }
}

class JikanAired {
  const JikanAired({this.from, this.to, this.prop, this.string});

  final DateTime? from;
  final DateTime? to;
  final JikanAiredProp? prop;
  final String? string;

  factory JikanAired.fromJson(Map<String, dynamic> json) {
    return JikanAired(
      from: json['from'] != null
          ? DateTime.tryParse(json['from'] as String)
          : null,
      to: json['to'] != null ? DateTime.tryParse(json['to'] as String) : null,
      prop: json['prop'] != null
          ? JikanAiredProp.fromJson(json['prop'] as Map<String, dynamic>)
          : null,
      string: json['string'] as String?,
    );
  }

  int? get year => from?.year ?? prop?.year;
}

class JikanAiredProp {
  const JikanAiredProp({this.day, this.month, this.year});

  final int? day;
  final int? month;
  final int? year;

  factory JikanAiredProp.fromJson(Map<String, dynamic> json) {
    return JikanAiredProp(
      day: json['day'] as int?,
      month: json['month'] as int?,
      year: json['year'] as int?,
    );
  }
}

class JikanBroadcast {
  const JikanBroadcast({this.day, this.time, this.timezone, this.string});

  final String? day;
  final String? time;
  final String? timezone;
  final String? string;

  factory JikanBroadcast.fromJson(Map<String, dynamic> json) {
    return JikanBroadcast(
      day: json['day'] as String?,
      time: json['time'] as String?,
      timezone: json['timezone'] as String?,
      string: json['string'] as String?,
    );
  }
}

class JikanProducer {
  const JikanProducer({
    required this.malId,
    required this.type,
    required this.name,
    this.url,
  });

  final int malId;
  final String type;
  final String name;
  final String? url;

  factory JikanProducer.fromJson(Map<String, dynamic> json) {
    return JikanProducer(
      malId: json['mal_id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String?,
    );
  }
}

class JikanGenre {
  const JikanGenre({
    required this.malId,
    required this.type,
    required this.name,
    this.url,
  });

  final int malId;
  final String type;
  final String name;
  final String? url;

  factory JikanGenre.fromJson(Map<String, dynamic> json) {
    return JikanGenre(
      malId: json['mal_id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String?,
    );
  }
}

class JikanImages {
  const JikanImages({this.jpg, this.webp});

  final JikanImageSet? jpg;
  final JikanImageSet? webp;

  factory JikanImages.fromJson(Map<String, dynamic> json) {
    return JikanImages(
      jpg: json['jpg'] != null
          ? JikanImageSet.fromJson(json['jpg'] as Map<String, dynamic>)
          : null,
      webp: json['webp'] != null
          ? JikanImageSet.fromJson(json['webp'] as Map<String, dynamic>)
          : null,
    );
  }
}

class JikanImageSet {
  const JikanImageSet({this.imageUrl, this.smallImageUrl, this.largeImageUrl});

  final String? imageUrl;
  final String? smallImageUrl;
  final String? largeImageUrl;

  factory JikanImageSet.fromJson(Map<String, dynamic> json) {
    return JikanImageSet(
      imageUrl: json['image_url'] as String?,
      smallImageUrl: json['small_image_url'] as String?,
      largeImageUrl: json['large_image_url'] as String?,
    );
  }
}

class JikanTrailer {
  const JikanTrailer({this.youtubeId, this.url, this.embedUrl, this.images});

  final String? youtubeId;
  final String? url;
  final String? embedUrl;
  final JikanTrailerImages? images;

  factory JikanTrailer.fromJson(Map<String, dynamic> json) {
    return JikanTrailer(
      youtubeId: json['youtube_id'] as String?,
      url: json['url'] as String?,
      embedUrl: json['embed_url'] as String?,
      images: json['images'] != null
          ? JikanTrailerImages.fromJson(json['images'] as Map<String, dynamic>)
          : null,
    );
  }
}

class JikanTrailerImages {
  const JikanTrailerImages({
    this.imageUrl,
    this.smallImageUrl,
    this.mediumImageUrl,
    this.largeImageUrl,
    this.maximumImageUrl,
  });

  final String? imageUrl;
  final String? smallImageUrl;
  final String? mediumImageUrl;
  final String? largeImageUrl;
  final String? maximumImageUrl;

  factory JikanTrailerImages.fromJson(Map<String, dynamic> json) {
    return JikanTrailerImages(
      imageUrl: json['image_url'] as String?,
      smallImageUrl: json['small_image_url'] as String?,
      mediumImageUrl: json['medium_image_url'] as String?,
      largeImageUrl: json['large_image_url'] as String?,
      maximumImageUrl: json['maximum_image_url'] as String?,
    );
  }
}

class JikanRelation {
  const JikanRelation({this.relation, this.entry = const []});

  final String? relation;
  final List<JikanRelationEntry> entry;

  factory JikanRelation.fromJson(Map<String, dynamic> json) {
    return JikanRelation(
      relation: json['relation'] as String?,
      entry:
          (json['entry'] as List?)
              ?.map(
                (e) => JikanRelationEntry.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}

class JikanRelationEntry {
  const JikanRelationEntry({this.malId, this.type, this.name, this.url});

  final int? malId;
  final String? type;
  final String? name;
  final String? url;

  factory JikanRelationEntry.fromJson(Map<String, dynamic> json) {
    return JikanRelationEntry(
      malId: json['mal_id'] as int?,
      type: json['type'] as String?,
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }
}

class JikanTheme {
  const JikanTheme({this.openings = const [], this.endings = const []});

  final List<String> openings;
  final List<String> endings;

  factory JikanTheme.fromJson(Map<String, dynamic> json) {
    return JikanTheme(
      openings:
          (json['openings'] as List?)?.map((e) => e as String).toList() ??
          const [],
      endings:
          (json['endings'] as List?)?.map((e) => e as String).toList() ??
          const [],
    );
  }
}

class JikanExternal {
  const JikanExternal({this.name, this.url});

  final String? name;
  final String? url;

  factory JikanExternal.fromJson(Map<String, dynamic> json) {
    return JikanExternal(
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }
}

class JikanStreaming {
  const JikanStreaming({this.name, this.url});

  final String? name;
  final String? url;

  factory JikanStreaming.fromJson(Map<String, dynamic> json) {
    return JikanStreaming(
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }
}
