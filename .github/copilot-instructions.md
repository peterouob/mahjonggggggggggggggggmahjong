# Copilot Instructions

## Project

**麻將找人定位系統** — a location-based real-time mahjong player matching app.

- **Backend**: Go + Gin (REST) + Gorilla WebSocket, module name `mahjong`
- **Database**: MySQL + GORM, Redis (GeoSet, Pub/Sub, rate limiting, cache)
- **Frontend**: React 19 + TypeScript + Vite + Tailwind CSS (in `frontend/`)

> The architecture spec in `README.md` and `CLAUDE.md` describes GraphQL + PostgreSQL as the production target. The current implementation uses REST + MySQL instead — see `IMPLEMENTATION.md` for why.

## Commands

```bash
# Backend — run from repo root
go run .                   # start server
go test -race ./...        # run all tests
go test -race ./internal/service/...  # run a single package
golangci-lint run          # lint
go mod tidy                # after changing dependencies
docker compose up --build  # start MySQL + Redis + app

# Frontend — from frontend/
npm run dev       # dev server (http://localhost:5173)
npm run build     # TypeScript check + Vite build
npm run lint      # ESLint
```

Copy `.env.example` → `.env` before first run (defaults work with docker-compose).

## Architecture

### Layer structure

```
main.go              → wires everything, graceful shutdown
internal/
  config/            → Viper config (env vars + .env file)
  domain/models.go   → ALL domain types and GORM models (single file)
  handler/           → Gin HTTP handlers; thin — bind input, call service, respond
  service/           → business logic; returns *apierror.APIError on failure
  repository/        → GORM DB access; one file per aggregate
  middleware/        → NoAuth (X-User-ID header), RateLimit (Redis fixed-window)
  router/router.go   → all routes and rate-limit middleware wiring
  hub/hub.go         → WebSocket hub + Redis Pub/Sub fan-out
pkg/
  apierror/          → APIError type and constructor helpers
  cache/             → Redis client wrapper
  database/          → MySQL connection
  utils/geo.go       → Haversine distance, coordinate blurring
```

### Request flow

```
HTTP/WS client
  → Gin router (cors, logger, recovery)
  → middleware.NoAuth() → reads X-User-ID header (MVP; no JWT)
  → middleware.RateLimit() → Redis fixed-window counter
  → handler → service → repository (GORM/MySQL) + cache (Redis)
```

For WebSocket: `GET /ws?user_id=<id>` — hub registers the client, starts `PSubscribe("mahjong:user:*")` on Redis, and routes messages to the matching in-process connection.

### WebSocket event delivery

Services publish to `mahjong:user:{userID}` (personal channel). The hub uses a **single** `PSubscribe("mahjong:user:*")` connection and routes messages to the correct `*Client` by extracting the userID from the channel name. `NotificationService` queries `geo:online_users` (Redis GeoSearch) to determine which users within 5 km should receive a broadcast event, then publishes to each of their personal channels.

## Key Conventions

### Auth (MVP)
The router uses `middleware.NoAuth()` which reads the caller's identity from the `X-User-ID` header — not a JWT Bearer token. `middleware.GetUserID(c)` retrieves it in handlers.

### Error handling
Services return `*apierror.APIError`. Handlers pass it directly to `respondError(c, err)`. All error codes are defined as constants in `pkg/apierror/errors.go`. Error responses have the shape `{"error": {"code": "...", "message": "..."}}`.

### Single-active-broadcast constraint
MySQL lacks `EXCLUDE USING gist(...)`. The constraint is enforced at the service layer: `BroadcastService.Start` calls `GetActiveByPlayerID` before inserting. Same pattern for single-room-seat in `RoomService.Join`.

### Domain models
All GORM models and domain types live in `internal/domain/models.go`. UUIDs are assigned in `BeforeCreate` hooks. `Friendship` rows are always stored with `UserIDA < UserIDB` (lexicographic) — query helpers must normalise the pair before lookup.

### Redis key design

| Key | Type | TTL | Purpose |
|-----|------|-----|---------|
| `geo:broadcasts` | GeoSet | app-managed | Active broadcast locations |
| `geo:online_users` | GeoSet | app-managed | Connected users' last location |
| `broadcast:ttl:{playerID}` | String | 10 min | Heartbeat sentinel |
| `friends:{userID}` | Set | 10 min | Friend ID cache |
| `blocked:{userID}` | Set | 1 hr | Block cache |
| `jwt:blacklist:{jti}` | String | token TTL | Revoked tokens |
| `rate:{userID}:{action}:{window}` | String | 2× window | Rate-limit counter |
| `mahjong:user:{userID}` | Pub/Sub | — | WebSocket delivery channel |

### Location update threshold
`PATCH /broadcasts/:id/location` accepts up to 60 req/min but only publishes a `broadcast.updated` WebSocket event when the player has moved ≥ 50 m (Haversine check in `BroadcastService.UpdateLocation`).

### Account age restriction
`user.CanBroadcast()` returns false if the account is < 24 hours old. Called at the start of `BroadcastService.Start`, `RoomService.Create/Join`, and `SocialService.SendFriendRequest`.

### FCM stub
`service/notification.go` contains a `fcmPush` stub that logs to stdout. To enable real push, replace the stub body with Firebase SDK calls — no other files need changing.
