import '../api/api_config.dart';
import '../api/json_utils.dart';
import '../utils/format.dart';
import 'anime_release.dart';

class FranchiseEntry {
  const FranchiseEntry({required this.order, required this.release});

  final int order;
  final AnimeRelease release;
}

class AnimeFranchise {
  const AnimeFranchise({
    required this.id,
    required this.name,
    required this.englishName,
    required this.imagePath,
    required this.releases,
  });

  final String id;
  final String name;
  final String? englishName;
  final String? imagePath;
  final List<FranchiseEntry> releases;

  factory AnimeFranchise.fromJson(Map<String, dynamic> json) {
    final entries =
        asMapList(json['franchise_releases'])
            .map((item) {
              final release = asMap(item['release']);
              if (release.isEmpty) return null;
              return FranchiseEntry(
                order: asInt(item['sort_order']) ?? 0,
                release: AnimeRelease.fromJson(release),
              );
            })
            .whereType<FranchiseEntry>()
            .toList()
          ..sort((a, b) {
            final yearA = a.release.year ?? 0;
            final yearB = b.release.year ?? 0;
            if (a.order != b.order) return a.order.compareTo(b.order);
            return yearA.compareTo(yearB);
          });

    return AnimeFranchise(
      id: asString(json['id']) ?? '',
      name: asString(json['name']) ?? 'франшиза',
      englishName: asString(json['name_english']),
      imagePath: asString(asMap(json['image'])['preview']),
      releases: entries,
    );
  }

  String get displayName => lc(name);

  String? get imageUrl => ApiConfig.mediaUrl(imagePath);

  List<AnimeRelease> relatedTo(int releaseId) {
    final result = <AnimeRelease>[];
    final seen = <int>{releaseId};
    for (final entry in releases) {
      if (seen.add(entry.release.id)) result.add(entry.release);
    }
    return result;
  }
}

List<AnimeRelease> relatedReleasesFor(
  List<AnimeFranchise> franchises,
  int releaseId,
) {
  final result = <AnimeRelease>[];
  final seen = <int>{releaseId};
  for (final franchise in franchises) {
    for (final entry in franchise.releases) {
      if (seen.add(entry.release.id)) result.add(entry.release);
    }
  }
  result.sort((a, b) {
    final yearA = a.year ?? 0;
    final yearB = b.year ?? 0;
    if (yearA != yearB) return yearA.compareTo(yearB);
    return a.id.compareTo(b.id);
  });
  return result;
}
