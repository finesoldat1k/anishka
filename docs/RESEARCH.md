# Research & Architecture Notes

This document captures the API evaluation, technical decisions, and implementation
details for **anishka**. It is meant for maintainers and future contributors.

---

## 1. API Evaluation: AniLibria vs Alternatives

| Criteria | AniLibria v4 | Shikimori / AniList | Custom Aggregator |
|----------|--------------|---------------------|-------------------|
| **Auth required** | ❌ No | ✅ OAuth | ✅ Optional |
| **Russian metadata** | ✅ Native | ✅ Via community | Manual |
| **HLS streams** | ✅ Master playlists (480/720/1080) | ❌ Links only | Manual |
| **Franchise graph** | ✅ `/anime/releases/franchise` | ✅ Relations | Manual |
| **CORS (API)** | ✅ `access-control-allow-origin: *` | ✅ | N/A |
| **CORS (HLS)** | ✅ `access-control-allow-origin: *` | N/A | N/A |
| **CORS (Images)** | ❌ Missing | ✅ Usually | N/A |
| **Rate limits** | Undocumented, generous | Strict | N/A |
| **Stability** | Years of operation | Official | N/A |

**Decision**: hybrid setup.

- **Shikimori** (`https://shikimori.io/api`) is the catalog and metadata
  source: ongoing lists, search, details, genres, franchise relations,
  YouTube trailers and episode screenshots. No OAuth is required for these
  public endpoints. Use the `.io` host: `shikimori.one` redirects and
  breaks browser CORS.
- **AniList** (`https://graphql.anilist.co`) and **Kitsu**
  (`https://kitsu.io/api/edge`) enrich metadata with English titles,
  scores, posters/banners and descriptions when Shikimori data is thin.
  Both are public, CORS-friendly and optional.
- **AniLibria v4** (`https://anilibria.top/api/v1`) is the primary
  playback source. Releases are resolved by Shikimori ID
  (`shikimori.id`), which is more reliable than matching Russian titles.
- **AnimeVost / AniDub / Kodik** adapters add fallback voices and streams.
  Scraped sources are best-effort: searches are capped at 8 s and details
  at 6 s, and browser CORS failures degrade gracefully.

### Key Endpoints Used

Shikimori:

| Endpoint | Purpose |
|----------|---------|
| `GET /animes?status=ongoing&limit=…` | Home "ongoing" grid |
| `GET /animes?search=…` | Catalog search |
| `GET /animes/{id}` | Details, genres, studios, videos |
| `GET /animes/{id}/screenshots` | Episode stills for the details gallery |
| `GET /animes?franchise=…` | Related releases |

AniList / Kitsu:

| Endpoint | Purpose |
|----------|---------|
| `POST https://graphql.anilist.co` (`Media(search: …)`) | Trailer, banner, score, English title, description, genres, studios |
| `GET https://kitsu.io/api/edge/anime?filter[text]=…` | Extra poster/cover, rating, synopsis, YouTube id |

AniLibria:

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `GET /anime/releases/latest?limit=50` | Home fallback grid | `AnimeRelease[]` |
| `GET /anime/releases/{id}` | Full release: episodes + voices | `AnimeRelease` |
| `GET /anime/catalog/releases?f[search]=…` | Search by title | compact `AnimeRelease[]` |
| `GET /anime/releases/franchise?id=…` | Legacy related releases | `AnimeRelease[]` |

> **Important**: AniLibria catalog search returns *compact* releases
> without `members` or `episodes`. Always call `/anime/releases/{id}`
> before building playback sources.

### Response Shapes (abridged)

```json
// AnimeRelease (simplified)
{
  "id": 10303,
  "names": { "ru": "Название", "en": "Title" },
  "poster": {
    "src": "/storage/releases/posters/10303/….jpg",
    "preview": "/storage/releases/posters/10303/….jpg",
    "thumbnail": "/storage/releases/posters/10303/….jpg",
    "optimized": { "src": "….webp", "preview": "….webp", "thumbnail": "….webp" }
  },
  "background": { "src": "…" },
  "episodes": [
    {
      "ordinal": 1,
      "name": "Эпизод 1",
      "hls_480": "https://cache.libria.fun/…/480/….m3u8?…",
      "hls_720": "https://cache.libria.fun/…/720/….m3u8?…",
      "hls_1080": "https://cache.libria.fun/…/1080/….m3u8?…"
    }
  ],
  "members": [
    { "role": { "value": "voicing" }, "name": "AniDUB" }
  ],
  "genres": [{ "name": "фэнтези" }],
  "season": { "year": 2024, "season": "summer" }
}
```

### Dub / Voice Handling

- AniLibria `members[]` with `role.value == "voicing"` are cast names, not
  separate studio tracks. They are grouped into **one** `AniLibriaVoiceover`
  per release: title `anilibria`, subtitle `озвучка студии · names`, id
  `anilibria_{releaseId}`. Cast names remain visible but never replace the
  source name in the picker.
- Additional sources expose their own `GenericVoiceover` (`animevost`,
  `anidub`, `kodik`) so the picker lists real source names.
- Episode HLS URLs are per-release, not per-voice. The picker changes the
  voice label/source and keeps the selected episode ordinal.
- `AnimeSource` represents one source + voice combination. The playback
  sheet merges `AnimeSource` objects from all providers into one voice
  chip list, so choosing any chip switches to that source's stream.

### Scraped Sources (AnimeVost / AniDub)

- **AnimeVost**: DLE search (`POST /index.php?do=search`) → release page.
  Episode ids live in an inline object:
  `var data = {"1 серия":"1451327130",...};`. Some pages add a trailing
  comma before `}`, which is not valid JSON, so the parser strips it
  before `jsonDecode`. Streams resolve lazily via
  `/frame5.php?play={id}` (MP4 mirrors, CORS `*`) with
  `/getlink.php?id={id}` as a fallback.
- **AniDub**: DLE search → release page → Sibnet episode ids from the
  inline tabs. Playback resolves a Sibnet shell URL; `video.sibnet.ru`
  currently returns `403` in some environments, so the episode may not
  play even though it is listed.
- Both HTML endpoints are **not CORS-enabled**. They work on native
  builds; the web build silently falls back to AniLibria only.
- Scraped releases use the Shikimori anime id as their `libraryId`, so
  progress/favorites from different sources never collide on id `0`.

### Image CORS Issue

- API & HLS: `access-control-allow-origin: *` ✅
- Images (`anilibria.top/storage/…`): **no CORS headers** ❌
- **Workaround**: Web uses `Image.network(url, webHtmlElementStrategy: WebHtmlElementStrategy.prefer)` which renders via an HTML `<img>` platform view, bypassing canvas/CORS. Native uses `CachedNetworkImage`.

---

## 2. Architecture Overview

### Dependency Graph (simplified)

```
main.dart
  ├─ Provider<AnimeRepository>
  ├─ Provider<LibraryStore>
  ├─ GoRouter (/, /search, /about, /anime/:id, /anime/shikimori/:id, /watch/:id/:episode)
  └─ MaterialApp.router (AppTheme)

AnimeRepository
  ├─ ShikimoriApi (catalog + details + franchise + screenshots)
  ├─ AniListApi / KitsuApi (optional metadata enrichment)
  ├─ AnilibriaApi (release resolution + streams)
  ├─ VideoSourceManager (AniLibria, AnimeVost, AniDub, Kodik)
  └─ Models (AnimeRelease, ShikimoriAnime, AnimeSource, VoiceoverInfo)

LibraryStore
  └─ SharedPreferences (anishka.library.v1, anishka.progress.v1)

PlayerScreen
  ├─ Player (media_kit)
  ├─ VideoController + VideoSurface (media_kit_video)
  ├─ Custom controls (seek, volume, speed, quality, episodes)
  └─ Keyboard shortcuts / gestures
```

### State Management

- **Provider + ChangeNotifier** for `LibraryStore` and repository caching.
- **No Riverpod/Bloc** — keeps bundle small and learning curve low.
- `go_router` for declarative routes with typed parameters.

### Persistence (`shared_preferences`)

| Key | Schema | Purpose |
|-----|--------|---------|
| `anishka.library.v1` | `Map<String, LibraryEntry>` | Favorites, status (plan/watching/completed), per-release |
| `anishka.progress.v1` | `Map<String, int>` | `releaseId:episodeOrdinal` → `positionSeconds` |

`LibraryEntry`:
```dart
{
  "status": "watching",      // "plan" | "watching" | "completed"
  "favorite": true,
  "progress": 3,             // last watched episode ordinal
  "updatedAt": 1726500000000 // ms epoch
}
```

---

## 3. Player Implementation Details

### media_kit Stack

| Package | Version | Role |
|---------|---------|------|
| `media_kit` | 1.2.6 (vendored) | Core player, platform abstraction |
| `media_kit_video` | 2.0.1 | Flutter `Video` widget, `VideoController` |
| `media_kit_libs_video` | 1.0.7 | Bundled ffmpeg/mpv (Android, iOS, macOS, Windows) |
| `media_kit_libs_linux` | 1.2.1 | Dynamically links system `libmpv.so.2` |

### Web HLS Flow

1. `Player.open(Media(hlsUrl))` → `WebPlayer` creates `<video>`.
2. `WebPlayer._loadSource()` detects `.m3u8` → calls `HLS.ensureInitialized()`.
3. `HLS.ensureInitialized()` injects `<script src="assets/packages/media_kit/assets/web/hls1.4.10.js">`.
4. `Hls.isSupported()` → `true` in Firefox/Chromium (MSE), `false` in Safari (native HLS).
5. `new Hls().loadSource(url).attachMedia(videoElement)` → hls.js takes over.
6. `videoElement.play()` → playback starts.

### Vendored media_kit Patch (Linux Crash Fix)

**Problem**: On some Linux systems (mpv 0.41 + libluajit 5.1), mpv’s built-in
`console.lua` script causes a `SIGSEGV` in the `lua/console` thread during
`mpv_initialize()`.

**Fix** (`third_party/media_kit/lib/src/player/native/player/real.dart`):
Before `mpv_initialize()`, set mpv options to disable **all** built-in Lua
scripts:
```dart
for (final opt in [
  'load-scripts', 'load-console', 'load-context-menu',
  'load-commands', 'load-positioning', 'load-select',
  'load-stats-overlay', 'load-auto-profiles', 'ytdl',
]) {
  mpvSetOptionString(handle, opt, 'no'.toNativeUtf8());
}
```

**Upgrade Procedure** (see `third_party/media_kit/PATCHES.md`):
1. `flutter pub upgrade media_kit` → note new version.
2. Copy patched `real.dart` to new version’s source.
3. Update `dependency_overrides` path in `pubspec.yaml`.
4. Run `flutter test`, `flutter build linux`, verify no `lua/*` threads.

### Custom VideoSurface (Web)

`media_kit_video`’s `Video` widget waits for `width/height` from the
`<video>` element before inserting the platform view. In Firefox, a
detached `<video>` never fires `loadedmetadata`, so the view never mounts.

**Solution** (`lib/ui/widgets/video_surface.dart`):
- On web, render `HtmlElementView` immediately with a fallback 16:9 size
  (1920×1080).
- Once `controller.rect` updates with real dimensions, the `FittedBox`
  re-lays out automatically.
- Native platforms continue using the standard `Video` widget.

### Controls & Shortcuts

| Action | Mouse | Keyboard |
|--------|-------|----------|
| Play/Pause | Double-tap / center tap | Space / K |
| Seek ±10s | — | ← / → |
| Seek ±60s | — | Shift+← / Shift+→ |
| Volume ±10% | — | ↑ / ↓ |
| Speed cycle | — | S |
| Quality menu | Top-right button | Q |
| Episode picker | Top-right button | E |
| Fullscreen | Double-tap / button | F |
| Mute | — | M |
| Next/Prev episode | — | N / P |
| Skip OP/ED | Skip button (when raised) | — |
| Exit player | — | Escape |

---

## 4. UI / Theming

### Colors

| Role | Hex | Usage |
|------|-----|-------|
| Background | `#060409` | App root, scaffolds |
| Surface | `#0f0c13` | Cards, sheets, app bar |
| Accent (violet) | `#a970ff` | Primary buttons, selection, focus |
| Accent hover | `#c094ff` | Button hover, active tab |
| Text primary | `#f5f1fa` | Body, headings |
| Text muted | `#8a8294` | Secondary labels, placeholders |
| Border | `#1e1a24` | Dividers, input outlines |
| Error | `#ff6b6b` | Error states, snackbar |

### Typography

- **Headings**: `Unbounded` (variable, wght 400–800)
- **Body**: `Onest` (variable, wght 400–800)
- **Generation**: `dart run google_fonts:generate_fonts` → bundles
  `assets/fonts/Unbounded-*.ttf`, `Onest-*.ttf`.
- **All text lowercase**: enforced via `.lc` extension on API strings
  and hardcoded lowercase in Dart.

### Responsive Breakpoints

| Width | Layout |
|-------|--------|
| `< 600` | Mobile: 2-col grid, bottom nav, immersive player |
| `600–1024` | Tablet: 3-col grid, side drawer |
| `> 1024` | Desktop: 4–5-col grid, persistent sidebar |

---

## 5. Testing Strategy

| Layer | Tool | Coverage |
|-------|------|----------|
| Unit (models, format, storage, APIs, parsers) | `flutter_test` | `test/*.dart` (27 tests) |
| Widget (screens, widgets) | `flutter_test` | Smoke tests for Home, Details, Library |
| Integration (player) | Manual / device | HLS playback, seek, quality, episodes |
| Static analysis | `flutter analyze` | Zero issues (excludes `third_party/**`) |

Run all:
```bash
flutter analyze
flutter test
flutter build web --release
flutter build linux --release
```

---

## 6. Known Limitations / TODO

- [ ] **Windows build** — needs CI or Windows runner (MSIX / Store).
- [ ] **Android build** — untested; verify `media_kit_libs_android_video`,
      permissions, ProGuard rules.
- [ ] **Image rounding on web** — HTML `<img>` platform views don’t clip
      to `border-radius` / overflow in Flutter’s compositor. Acceptable
      for now; could swap to a custom `<canvas>`-backed platform view.
- [ ] **Schedule / Calendar** — Shikimori `/animes?status=ongoing` and the
      AniLibria schedule endpoint exist but are not wired to a calendar.
- [ ] **Offline download** — media_kit supports file download; not exposed.
- [ ] **Subtitles** — AniLibria provides embedded subs; `media_kit` + libass
      works on native; web needs `libass.js` or WebVTT conversion.
- [ ] **Scraped fallback sources** — AnimeVost and AniDub block browser CORS
      and can change their HTML at any time. They work best on native builds;
      Kodik needs an optional API token. AniDub playback depends on Sibnet,
      which currently returns `403` in some environments. AnimeVost
      `getlink.php` mirrors can point at hosts with unreliable DNS;
      `frame5.php` MP4 mirrors are the working path.
- [ ] **Built-in trailer on native** — the YouTube iframe is web-only; Linux,
      Windows and Android open the trailer in an external browser instead.
- [ ] **YouTube bot check** — headless/embedded players may show
      "Sign In to confirm you're not a bot". The details card avoids this by
      showing a thumbnail and loading the iframe only on tap.
- [ ] **Analytics / Crashlytics** — intentionally omitted for privacy.

---

## 7. References

- Shikimori API docs: <https://shikimori.one/api/doc>
- AniLibria API docs: <https://anilibria.top/api/docs/v1>
- media_kit repo: <https://github.com/media-kit/media-kit>
- hls.js: <https://github.com/video-dev/hls.js>
- Flutter Web platform views: <https://docs.flutter.dev/platform-integration/web/platform-views>
- mpv options: <https://mpv.io/manual/master/#options>