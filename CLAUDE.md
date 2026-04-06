# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains the architecture specification for **麻將找人定位系統** (Mahjong Player Locator System) — a location-based real-time mahjong player matching mobile app. The primary source of truth is `README.md` (v2.0, 2026-03-28), a comprehensive design document covering product requirements, system architecture, API design, database schema, and development milestones.

There is currently no source code — this is a pre-implementation design spec. When implementation begins, the structure below applies.

## Planned Tech Stack

- **Backend**: Go + gqlgen (GraphQL, schema-first codegen) + gRPC (inter-service)
- **Mobile**: Flutter/Dart + ferry (GraphQL client) + Riverpod 2.x (state management)
- **Data**: PostgreSQL + TimescaleDB (location history), Redis (Pub/Sub, GeoSet, cache, sessions)
- **Infrastructure**: Kubernetes (GKE/EKS), nginx (API gateway), Cloudflare (edge)

## Expected Commands (once code exists)

```bash
# Backend
docker-compose up          # Start local PostgreSQL + Redis + services
go test -race ./...        # Run tests with race detector
golangci-lint run          # Lint
gqlgen generate            # Regenerate GraphQL types after schema changes

# Flutter
flutter analyze            # Lint
flutter test               # Unit tests
flutter build ios          # iOS production build
flutter build apk          # Android production build
```

## Architecture

### Domain Boundaries (DDD — 5 Bounded Contexts)

| BC | Responsibility |
|----|---------------|
| **Identity** | OAuth (Apple/Google), JWT lifecycle, auth middleware |
| **Discovery** | Broadcast lifecycle, Redis GeoSet indexing, nearby search (5km), location TTL |
| **Room** | Room state machine (WAITING→FULL→PLAYING→CLOSED), seat management (4 players), game rules |
| **Social** | Friendships (bidirectional, normalized), block list, friend priority push |
| **Notification** | FCM integration, in-app events, WebSocket routing |

### Request Path

```
Flutter Client (HTTPS + WSS)
  → Cloudflare (DDoS/WAF/CDN)
  → nginx (SSL termination, rate limiting)
  → GraphQL Gateway (gqlgen, auth middleware, subscription hub)
  → Discovery/Room/Social/Notification services (gRPC)
  → Redis (Pub/Sub, GeoSet, cache)
  → PostgreSQL + TimescaleDB
```

### Key Patterns

**Dual-channel Pub/Sub** — Two separate Redis channels for different latency targets:
- `broadcast:friend:{userID}` — Friend broadcasts, instant push (< 100ms)
- `broadcast:geo:{geohash5}` — Stranger broadcasts, 500ms batch + dedup
- `broadcast:geo:{geohash5}:adj` — Adjacent cells (edge-case coverage)
- `room:update:{roomID}` — Room state changes
- `notification:push:{userID}` — FCM trigger signals

**Location Privacy** — Enforced at the GraphQL resolver layer (services always receive exact coords):
- Room in WAITING state: coordinates blurred ±150m + placeName only
- Room in FULL/PLAYING state: exact coordinates visible to members

**Publisher Interface** — Redis Pub/Sub is abstracted behind a `Publisher` interface to allow future migration to NATS JetStream without changing service code (ADR-001).

**Broadcast TTL** — 10-minute TTL via Redis keyspace notifications; clients send heartbeats. Location updates only propagate when movement > 50m threshold.

**Account Age Restriction** — Accounts < 24h old cannot create broadcasts, join rooms, or send friend requests (anti-abuse).

### Database Highlights

```sql
-- One ACTIVE broadcast per player (enforced at DB level)
broadcasts: EXCLUDE USING gist(player_id WITH =) WHERE (status='ACTIVE')

-- Player cannot be in two rooms simultaneously
room_seats: EXCLUDE USING btree(player_id WITH =) WHERE (player_id IS NOT NULL AND left_at IS NULL)

-- Normalized bidirectional friendships
friendships: CHECK (user_id_a < user_id_b) + UNIQUE (user_id_a, user_id_b)
```

TimescaleDB hypertable for location history: 1-day chunks, compression after 7 days, 30-day retention. Writes are batched (1,000 cap, 30s flush).

### Flutter Client Architecture

- **GraphQL subscriptions**: `ferry` + `gql_websocket_link` (graphql-ws protocol); auth token sent via `connection_init` message (not URL, to avoid log exposure — ADR-005)
- **State**: Riverpod 2.x `StreamProvider` for subscription streams
- **Maps**: flutter_map + OSM tiles (not Google Maps — unlimited markers, no API cost)
- **Offline**: Hive local cache for friends list and user data; exponential backoff reconnect with snapshot refetch on reconnection
- **Navigation**: GoRouter

### WebSocket Graceful Shutdown (Rolling Updates)

`preStop` hook: 30s sleep → stop accepting connections → broadcast restart signal to all subscriptions → wait for goroutines (max 30s) → flush location buffer → close connections. `terminationGracePeriodSeconds: 60`.

## MVP Scope

**P0 (blocking)**: OAuth login, broadcast start/update/stop, nearby broadcast discovery, Room CRUD, FCM notifications (join/full), age restriction, blocking
**P1**: Friend system, friend priority push, friend activity list
**P2 (v1.1)**: Friend broadcast notifications, read replicas, NATS migration consideration

Beta target: 300–500 users, Taipei only, Weeks 11–12. Exit gates: D1 retention ≥ 30%, first match success ≥ 40%, p99 API latency ≤ 500ms.
