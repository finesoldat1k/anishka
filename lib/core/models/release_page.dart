import 'anime_release.dart';

class ReleasePage {
  const ReleasePage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<AnimeRelease> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;

  factory ReleasePage.empty() =>
      const ReleasePage(items: [], page: 1, totalPages: 1, total: 0);
}
