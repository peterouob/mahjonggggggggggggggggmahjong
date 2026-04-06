# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run app
flutter run

# Run on specific device
flutter run -d ios
flutter run -d android

# Build
flutter build apk
flutter build ios

# Tests
flutter test                        # all tests
flutter test test/path/to/test.dart # single test

# Lint / analyze
flutter analyze

# Code generation (Ferry + Riverpod)
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch         # continuous

# Update dependencies
flutter pub get
flutter pub upgrade
```

## Architecture

This is a Flutter app for finding nearby Mahjong players in real-time. The README.md contains the full architecture specification agreed on by the team (v1.0, 2026-03-28).

**Current state**: MVP Phase 0 — architecture is fully designed, implementation has not started beyond `lib/main.dart` stub.

### Planned directory structure

```
lib/
├── main.dart                    # ProviderScope + GoRouter entry point
├── core/
│   ├── design/                  # Design system (colors, typography, spacing)
│   ├── network/                 # Ferry GraphQL client, auth/websocket links
│   ├── storage/                 # Hive + flutter_secure_storage
│   ├── location/                # Geolocator wrapper
│   ├── error/                   # AppException + structured error codes
│   └── router/                  # GoRouter configuration
├── features/
│   ├── auth/
│   ├── onboarding/
│   ├── map/                     # Core feature: real-time map of nearby players
│   ├── room/                    # Room management (4-person matching)
│   ├── friends/
│   ├── profile/
│   └── notification/            # FCM handling
├── graphql/
│   ├── operations/              # Hand-written .graphql files
│   └── schema.graphql           # Synced from backend (do not edit)
└── generated/                   # ferry_generator output (do not edit)
```

### Layered architecture (DDD-inspired)

```
Presentation (Widgets/Pages)
    ↑ ref.watch()
State (Riverpod Providers/Notifiers)
    ↑ calls
Domain (Use Cases + Entities)
    ↑ depends on
Data (Repository + Remote/Local DataSource)
```

- Features do not import each other's widgets — cross-feature navigation goes through GoRouter
- Domain models ≠ Ferry-generated GraphQL models; Repository handles the mapping
- `autoDispose` on subscription providers; `keepAlive` on critical infrastructure providers

### Key tech choices (final — do not substitute)

| Concern | Library | Reason |
|---|---|---|
| GraphQL | `ferry` ^0.15 | graphql-ws subscriptions, Riverpod integration, auto-reconnect |
| State | `flutter_riverpod` ^2.6 + `riverpod_generator` | StreamProvider for WebSocket subs, autoDispose cleanup |
| Routing | `go_router` ^14 | Deep linking, nested routing |
| Maps | `flutter_map` + OSM + `flutter_map_cache` | Pure Dart, no platform channel |
| Location | `geolocator` ^11 | Background mode, cross-platform |
| Local cache | `hive_ce` ^2 | Friends list, user profile snapshots |
| Secure store | `flutter_secure_storage` ^9 | JWT (Keychain/Keystore) |
| Push | `firebase_messaging` ^15 | FCM standard |
| Error tracking | `sentry_flutter` ^8 | Crash auto-reporting |
| Testing | `mocktail` + `alchemist` | Mocking + Golden tests |

**Explicitly excluded**: `google_maps_flutter`, `graphql_flutter`, `get_it`, `bloc`, `provider`, `get`/`getx`

### GraphQL / network

- Link chain: Auth Link → Split Link (Query/Mutation → HTTP, Subscription → WebSocket)
- JWT in `Authorization` header for Query/Mutation; in `connection_init` payload for WebSocket
- Token expiry: 15 min, auto-refresh on `UNAUTHENTICATED` GraphQL error
- WebSocket protocol: `graphql-ws` (not legacy `subscriptions-transport-ws`)

### State providers (planned)

**core/** infrastructure:
- `graphQLClientProvider`, `currentLocationProvider` (Stream\<Position\>), `secureStorageProvider`, `hiveBoxProvider`, `connectionStateProvider`

**features/** per-feature:
- Auth: `authStateProvider`, `currentUserProvider`
- Map: `nearbyBroadcastsProvider` (subscription), `nearbyPlayersMapProvider`
- Room: `nearbyRoomsProvider`, `currentRoomProvider`, `roomDetailProvider(id)`
- Friends: `friendsProvider`, `activeFriendBroadcastsProvider`

### Map layer stack (bottom → top)

1. TileLayer (OSM + flutter_map_cache)
2. RoomMarkerLayer (WAITING rooms)
3. StrangerClusterLayer (cluster at zoom < 14)
4. FriendMarkerLayer (always visible)
5. MyLocationLayer (position + 5km broadcast range circle)

### Routing

```
/onboarding
/login
/                     (MainShell — IndexedStack with BottomNavigationBar)
  /map                (default tab)
  /friends
  /profile
/room/create
/room/:id
/room/:id/full
```

Deep links: `mahjong://room/:id`

### Design tokens

- Primary: `#E85C26` (mahjong red)
- Secondary: `#2B5EAB` (blue)
- Background: `#F5F5F0` (rice paper white)
- Friend markers: 60×80px; Stranger markers: 40×40px

### Error handling

GraphQL `extensions.code` values map to typed `AppException` subclasses. UI behaviour is code-specific (e.g. `ROOM_FULL`, `UNAUTHENTICATED`). Network errors surface as a connectivity banner; reconnect uses exponential backoff with auto-resubscription.
