import '../api/api_config.dart';
import '../api/json_utils.dart';
import '../utils/format.dart';
import 'anime_episode.dart';
import 'shikimori_anime.dart';

class ReleaseMember {
  const ReleaseMember({
    required this.nickname,
    required this.roleValue,
    required this.roleLabel,
    required this.avatarPath,
  });

  final String nickname;
  final String roleValue;
  final String roleLabel;
  final String? avatarPath;

  factory ReleaseMember.fromJson(Map<String, dynamic> json) {
    final role = asMap(json['role']);
    final user = asMap(json['user']);
    return ReleaseMember(
      nickname: asString(json['nickname']) ?? '',
      roleValue: asString(role['value']) ?? '',
      roleLabel: asString(role['description']) ?? '',
      avatarPath: asString(asMap(user['avatar'])['preview']),
    );
  }

  String get displayName => lc(nickname);

  String? get avatarUrl => ApiConfig.mediaUrl(avatarPath);

  bool get isVoiceActor => roleValue == 'voicing';
}

class AnimeRelease {
  const AnimeRelease({
    required this.id,
    required this.alias,
    required this.name,
    required this.englishName,
    required this.description,
    required this.year,
    required this.type,
    required this.season,
    required this.ageRating,
    required this.shikimoriRating,
    required this.internalRating,
    required this.posterPath,
    required this.posterThumbPath,
    required this.backgroundPath,
    required this.isOngoing,
    required this.isInProduction,
    required this.episodesTotal,
    required this.genres,
    required this.members,
    required this.episodes,
    required this.publishDay,
    required this.blockedByGeo,
    required this.blockedByCopyrights,
    required this.freshAt,
    required this.notification,
    this.shikimoriId,
  });

  final int id;
  final String alias;
  final String name;
  final String? englishName;
  final String? description;
  final int? year;
  final String? type;
  final String? season;
  final String? ageRating;
  final double? shikimoriRating;
  final double? internalRating;
  final String? posterPath;
  final String? posterThumbPath;
  final String? backgroundPath;
  final bool isOngoing;
  final bool isInProduction;
  final int? episodesTotal;
  final List<String> genres;
  final List<ReleaseMember> members;
  final List<AnimeEpisode> episodes;
  final String? publishDay;
  final bool blockedByGeo;
  final bool blockedByCopyrights;
  final DateTime? freshAt;
  final String? notification;
  final int? shikimoriId;

  /// Local-only library snapshot for favourites/status before a playable
  /// source exists. The negative id keeps it separate from real AniLibria
  /// release ids; it is migrated to the real release once sources load.
  factory AnimeRelease.fromShikimoriDetails(ShikimoriAnimeDetails details) {
    return AnimeRelease(
      id: -details.id,
      alias: details.url,
      name: details.displayTitle,
      englishName: details.englishTitle,
      description: details.descriptionText,
      year: details.year,
      type: details.kindLabel,
      season: null,
      ageRating: details.rating,
      shikimoriRating: details.scoreValue,
      internalRating: null,
      posterPath: details.posterOriginalUrl,
      posterThumbPath: details.posterUrl,
      backgroundPath: details.backgroundUrl,
      isOngoing: details.isOngoing,
      isInProduction: details.status == 'anons',
      episodesTotal: details.episodeCount,
      genres: details.allGenres,
      members: const [],
      episodes: const [],
      publishDay: null,
      blockedByGeo: false,
      blockedByCopyrights: false,
      freshAt: null,
      notification: null,
      shikimoriId: details.id,
    );
  }

  factory AnimeRelease.fromJson(Map<String, dynamic> json) {
    final nameMap = asMap(json['name']);
    final poster = asMap(json['poster']);
    final optimized = asMap(poster['optimized']);
    final backgrounds = asMapList(json['background_covers']);
    final background = backgrounds.isEmpty
        ? const <String, dynamic>{}
        : backgrounds.first;
    final backgroundOptimized = asMap(background['optimized']);
    final episodes =
        asMapList(json['episodes'])
            .map(AnimeEpisode.fromJson)
            .where((episode) => episode.ordinal > 0)
            .toList()
          ..sort(
            (a, b) =>
                (a.sortOrder ?? a.ordinal).compareTo(b.sortOrder ?? b.ordinal),
          );

    return AnimeRelease(
      id: asInt(json['id']) ?? 0,
      alias: asString(json['alias']) ?? '',
      name: asString(nameMap['main']) ?? 'без названия',
      englishName:
          asString(nameMap['english']) ?? asString(nameMap['alternative']),
      description: asString(json['description']),
      year: asInt(json['year']),
      type:
          asString(asMap(json['type'])['description']) ??
          asString(asMap(json['type'])['value']),
      season: asString(asMap(json['season'])['description']),
      ageRating: asString(asMap(json['age_rating'])['label']),
      shikimoriRating: asDouble(asMap(json['shikimori'])['rating']),
      internalRating: asDouble(asMap(json['rating'])['average']),
      shikimoriId: asInt(asMap(json['shikimori'])['id']),
      posterPath:
          asString(optimized['preview']) ??
          asString(optimized['src']) ??
          asString(poster['preview']) ??
          asString(poster['src']),
      posterThumbPath:
          asString(optimized['thumbnail']) ??
          asString(poster['thumbnail']) ??
          asString(optimized['preview']) ??
          asString(poster['preview']) ??
          asString(poster['src']),
      backgroundPath:
          asString(backgroundOptimized['preview']) ??
          asString(background['preview']) ??
          asString(background['src']),
      isOngoing: asBool(json['is_ongoing']),
      isInProduction: asBool(json['is_in_production']),
      episodesTotal: asInt(json['episodes_total']),
      genres: asMapList(json['genres'])
          .map((genre) => asString(genre['name']))
          .whereType<String>()
          .toList(),
      members: asMapList(json['members'])
          .map(ReleaseMember.fromJson)
          .where((member) => member.nickname.isNotEmpty)
          .toList(),
      episodes: episodes,
      publishDay: asString(asMap(json['publish_day'])['description']),
      blockedByGeo: asBool(json['is_blocked_by_geo']),
      blockedByCopyrights: asBool(json['is_blocked_by_copyrights']),
      freshAt: asDate(json['fresh_at']),
      notification: asString(json['notification']),
    );
  }

  factory AnimeRelease.fromSnapshot(Map<String, dynamic> json) {
    return AnimeRelease(
      id: asInt(json['id']) ?? 0,
      alias: asString(json['alias']) ?? '',
      name: asString(json['name']) ?? 'без названия',
      englishName: asString(json['english']),
      description: asString(json['description']),
      year: asInt(json['year']),
      type: asString(json['type']),
      season: asString(json['season']),
      ageRating: asString(json['age_rating']),
      shikimoriRating: asDouble(json['score']),
      internalRating: null,
      posterPath: asString(json['poster']),
      posterThumbPath:
          asString(json['poster_thumb']) ?? asString(json['poster']),
      backgroundPath: asString(json['background']),
      isOngoing: asBool(json['is_ongoing']),
      isInProduction: asBool(json['is_in_production']),
      episodesTotal: asInt(json['episodes_total']),
      genres: (json['genres'] is List)
          ? (json['genres'] as List).map((item) => item.toString()).toList()
          : const [],
      members: const [],
      episodes: const [],
      publishDay: asString(json['publish_day']),
      blockedByGeo: asBool(json['blocked_by_geo']),
      blockedByCopyrights: asBool(json['blocked_by_copyrights']),
      freshAt: asDate(json['fresh_at']),
      notification: null,
      shikimoriId: asInt(json['shikimori_id']),
    );
  }

  Map<String, dynamic> toSnapshotJson() => {
    'id': id,
    'alias': alias,
    'name': name,
    'english': englishName,
    'description': description,
    'year': year,
    'type': type,
    'season': season,
    'age_rating': ageRating,
    'score': score,
    'poster': posterPath,
    'poster_thumb': posterThumbPath,
    'background': backgroundPath,
    'is_ongoing': isOngoing,
    'is_in_production': isInProduction,
    'episodes_total': episodesTotal,
    'genres': genres,
    'publish_day': publishDay,
    'blocked_by_geo': blockedByGeo,
    'blocked_by_copyrights': blockedByCopyrights,
    'fresh_at': freshAt?.toIso8601String(),
    'shikimori_id': shikimoriId,
  };

  /// Canonical key in the local library: the Shikimori id when it is known,
  /// otherwise the release id. Temporary Shikimori-only snapshots use a
  /// negative id, but they still resolve to the same library entry as the
  /// playable release (`shikimoriId` is always positive).
  int get libraryId {
    final canonical = shikimoriId ?? 0;
    return canonical > 0 ? canonical : id;
  }

  String get displayTitle => lc(name, fallback: 'без названия');

  String? get displayEnglish => lcOrNull(englishName);

  String get displayDescription {
    final value = description?.replaceAll('\r', '').trim();
    if (value == null || value.isEmpty) return 'описание пока не добавили.';
    return value.toLowerCase();
  }

  String? get posterUrl => ApiConfig.mediaUrl(posterPath);

  String? get posterThumbUrl =>
      ApiConfig.mediaUrl(posterThumbPath) ?? posterUrl;

  String? get backgroundUrl => ApiConfig.mediaUrl(backgroundPath) ?? posterUrl;

  double? get score {
    if (shikimoriRating != null && shikimoriRating! > 0) return shikimoriRating;
    if (internalRating != null && internalRating! > 0) return internalRating;
    return null;
  }

  int? get episodeCount {
    if (episodes.isNotEmpty) return episodes.length;
    if (episodesTotal != null && episodesTotal! > 0) return episodesTotal;
    return null;
  }

  bool get isBlocked => blockedByGeo || blockedByCopyrights;

  String get statusLabel {
    if (isOngoing) return 'онгоинг';
    if (isInProduction) return 'анонс';
    return 'завершён';
  }

  List<String> get displayGenres =>
      genres.map((genre) => genre.toLowerCase()).toList();

  List<ReleaseMember> get voiceActors =>
      members.where((member) => member.isVoiceActor).toList();

  String get voiceCastLabel {
    final actors = voiceActors.map((actor) => actor.displayName).toList();
    if (actors.isEmpty) return 'русская озвучка';
    return actors.take(3).join(', ');
  }

  String get primaryMeta => releaseMeta(
    year: year,
    type: type,
    season: season,
    episodes: episodeCount,
  );

  AnimeEpisode? episodeByOrdinal(int ordinal) {
    for (final episode in episodes) {
      if (episode.ordinal == ordinal) return episode;
    }
    return null;
  }

  AnimeEpisode? episodeById(String id) {
    for (final episode in episodes) {
      if (episode.id == id) return episode;
    }
    return null;
  }

  AnimeRelease copyWith({
    String? name,
    String? description,
    String? posterPath,
    String? posterThumbPath,
    String? backgroundPath,
    double? shikimoriRating,
    int? episodesTotal,
    List<String>? genres,
    List<ReleaseMember>? members,
    List<AnimeEpisode>? episodes,
    int? shikimoriId,
  }) {
    return AnimeRelease(
      id: id,
      alias: alias,
      name: name ?? this.name,
      englishName: englishName,
      description: description ?? this.description,
      year: year,
      type: type,
      season: season,
      ageRating: ageRating,
      shikimoriRating: shikimoriRating ?? this.shikimoriRating,
      internalRating: internalRating,
      posterPath: posterPath ?? this.posterPath,
      posterThumbPath: posterThumbPath ?? this.posterThumbPath,
      backgroundPath: backgroundPath ?? this.backgroundPath,
      isOngoing: isOngoing,
      isInProduction: isInProduction,
      episodesTotal: episodesTotal ?? this.episodesTotal,
      genres: genres ?? this.genres,
      members: members ?? this.members,
      episodes: episodes ?? this.episodes,
      publishDay: publishDay,
      blockedByGeo: blockedByGeo,
      blockedByCopyrights: blockedByCopyrights,
      freshAt: freshAt,
      notification: notification,
      shikimoriId: shikimoriId ?? this.shikimoriId,
    );
  }

  /// Empty placeholder for legacy flow compatibility.
  static AnimeRelease empty() => const AnimeRelease(
    id: 0,
    alias: '',
    name: '',
    englishName: null,
    description: null,
    year: null,
    type: null,
    season: null,
    ageRating: null,
    shikimoriRating: null,
    internalRating: null,
    posterPath: null,
    posterThumbPath: null,
    backgroundPath: null,
    isOngoing: false,
    isInProduction: false,
    episodesTotal: null,
    genres: [],
    members: [],
    episodes: [],
    publishDay: null,
    blockedByGeo: false,
    blockedByCopyrights: false,
    freshAt: null,
    notification: null,
    shikimoriId: null,
  );
}
