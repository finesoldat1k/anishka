// Common interface for anime items displayed in cards/grids.
import 'anime_release.dart';
import 'shikimori_anime.dart';

/// Unified interface for anime items that can be displayed in cards.
abstract class AnimeCardItem {
  int get id;
  String get displayTitle;
  String? get posterUrl;
  String? get posterThumbUrl;
  double? get score;
  int? get year;
  int? get episodeCount;
  String? get ageRating;
  String? get statusLabel;
  bool get isOngoing;

  /// For library: the AniLibria release ID (for status/progress lookup)
  int? get libraryId => id;

  /// Whether this item has playback sources available
  bool get hasSources => false;
}

/// Extension to provide AnimeCardItem API for AnimeRelease.
extension AnimeReleaseCardItem on AnimeRelease {
  int get cardId => id;

  String get cardDisplayTitle => displayTitle;

  String? get cardPosterUrl => posterUrl;

  String? get cardPosterThumbUrl => posterThumbUrl;

  double? get cardScore => score;

  int? get cardYear => year;

  int? get cardEpisodeCount => episodeCount;

  String? get cardAgeRating => ageRating;

  String get cardStatusLabel => statusLabel;

  bool get cardIsOngoing => isOngoing;

  int? get cardLibraryId => id;

  bool get cardHasSources => episodes.isNotEmpty;
}

/// Extension to provide AnimeCardItem API for ShikimoriAnime.
extension ShikimoriAnimeCardItem on ShikimoriAnime {
  int get cardId => id;

  String get cardDisplayTitle => displayTitle;

  String? get cardPosterUrl => posterUrl;

  String? get cardPosterThumbUrl => posterUrl;

  double? get cardScore => double.tryParse(score);

  int? get cardYear => year;

  int? get cardEpisodeCount =>
      episodes > 0 ? episodes : (episodesAired > 0 ? episodesAired : null);

  String? get cardAgeRating => null;

  String get cardStatusLabel => statusLabel;

  bool get cardIsOngoing => status == 'ongoing';

  int? get cardLibraryId => null;

  bool get cardHasSources => false;
}

/// Extension to provide AnimeCardItem API for ShikimoriAnimeDetails.
extension ShikimoriAnimeDetailsCardItem on ShikimoriAnimeDetails {
  int get cardId => id;

  String get cardDisplayTitle => displayTitle;

  String? get cardPosterUrl => posterUrl;

  String? get cardPosterThumbUrl => posterUrl;

  double? get cardScore => double.tryParse(score);

  int? get cardYear => year;

  int? get cardEpisodeCount =>
      episodes > 0 ? episodes : (episodesAired > 0 ? episodesAired : null);

  String? get cardAgeRating => rating;

  String get cardStatusLabel => statusLabel;

  bool get cardIsOngoing => status == 'ongoing';

  int? get cardLibraryId => null;

  bool get cardHasSources => false;
}

/// Helper to extract card properties from any supported type.
class AnimeCardAdapter {
  final Object _item;

  AnimeCardAdapter(this._item);

  int get id {
    if (_item is AnimeRelease) return _item.cardId;
    if (_item is ShikimoriAnime) return _item.cardId;
    if (_item is ShikimoriAnimeDetails) return _item.cardId;
    throw ArgumentError('Unsupported type: ${_item.runtimeType}');
  }

  String get displayTitle {
    if (_item is AnimeRelease) return _item.cardDisplayTitle;
    if (_item is ShikimoriAnime) return _item.cardDisplayTitle;
    if (_item is ShikimoriAnimeDetails) return _item.cardDisplayTitle;
    throw ArgumentError('Unsupported type: ${_item.runtimeType}');
  }

  String? get posterUrl {
    if (_item is AnimeRelease) return _item.cardPosterUrl;
    if (_item is ShikimoriAnime) return _item.cardPosterUrl;
    if (_item is ShikimoriAnimeDetails) return _item.cardPosterUrl;
    return null;
  }

  String? get posterThumbUrl {
    if (_item is AnimeRelease) return _item.cardPosterThumbUrl;
    if (_item is ShikimoriAnime) return _item.cardPosterThumbUrl;
    if (_item is ShikimoriAnimeDetails) return _item.cardPosterThumbUrl;
    return null;
  }

  String? get backgroundUrl {
    if (_item is AnimeRelease) return _item.backgroundUrl;
    if (_item is ShikimoriAnime) return _item.backgroundUrl;
    if (_item is ShikimoriAnimeDetails) return _item.backgroundUrl;
    return null;
  }

  double? get score {
    if (_item is AnimeRelease) return _item.cardScore;
    if (_item is ShikimoriAnime) return _item.cardScore;
    if (_item is ShikimoriAnimeDetails) return _item.cardScore;
    return null;
  }

  int? get year {
    if (_item is AnimeRelease) return _item.cardYear;
    if (_item is ShikimoriAnime) return _item.cardYear;
    if (_item is ShikimoriAnimeDetails) return _item.cardYear;
    return null;
  }

  int? get episodeCount {
    if (_item is AnimeRelease) return _item.cardEpisodeCount;
    if (_item is ShikimoriAnime) return _item.cardEpisodeCount;
    if (_item is ShikimoriAnimeDetails) return _item.cardEpisodeCount;
    return null;
  }

  String? get ageRating {
    if (_item is AnimeRelease) return _item.cardAgeRating;
    if (_item is ShikimoriAnime) return _item.cardAgeRating;
    if (_item is ShikimoriAnimeDetails) return _item.cardAgeRating;
    return null;
  }

  String get statusLabel {
    if (_item is AnimeRelease) return _item.cardStatusLabel;
    if (_item is ShikimoriAnime) return _item.cardStatusLabel;
    if (_item is ShikimoriAnimeDetails) return _item.cardStatusLabel;
    return '';
  }

  bool get isOngoing {
    if (_item is AnimeRelease) return _item.cardIsOngoing;
    if (_item is ShikimoriAnime) return _item.cardIsOngoing;
    if (_item is ShikimoriAnimeDetails) return _item.cardIsOngoing;
    return false;
  }

  int? get libraryId {
    if (_item is AnimeRelease) return _item.cardLibraryId;
    if (_item is ShikimoriAnime) return _item.cardLibraryId;
    if (_item is ShikimoriAnimeDetails) return _item.cardLibraryId;
    return null;
  }

  bool get hasSources {
    if (_item is AnimeRelease) return _item.cardHasSources;
    if (_item is ShikimoriAnime) return _item.cardHasSources;
    if (_item is ShikimoriAnimeDetails) return _item.cardHasSources;
    return false;
  }
}
