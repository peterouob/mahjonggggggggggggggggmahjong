# Backend Implementation Log

> Maintained by the backend team. Records **what** was built, **why** each decision was made, and **what is deferred**. Update this file as each phase completes.

---

## Status: Phase 0 complete — MVP skeleton ready

---

## How to run locally

```bash
# 1. Copy env file
cp .env.example .env
# Edit .env if needed (defaults work for docker-compose)

# 2. Start infrastructure + app
docker compose up --build

# 3. Or run the app on the host (needs local MySQL + Redis running)
go run ./cmd/server
```

**Run tests (once written):**
```bash
go test -race ./...
```

**Run linter:**
```bash
golangci-lint run
```

**After changing dependencies:**
```bash
go mod tidy
```

---

## API Reference

All endpoints return `{"error": {"code": "...", "message": "..."}}` on failure.

### Auth

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/auth/register` | — | Register new user |
| POST | `/api/v1/auth/login` | — | Login, get token pair |
| POST | `/api/v1/auth/refresh` | — | Refresh access token |
| POST | `/api/v1/auth/logout` | Bearer | Blacklist current token |

### Broadcasts

| Method | Path | Rate limit | Description |
|--------|------|-----------|-------------|
| POST | `/api/v1/broadcasts` | 5/min | Start broadcast |
| GET | `/api/v1/broadcasts/nearby?lat=&lng=&radius_km=` | — | Nearby broadcasts (default 5 km) |
| GET | `/api/v1/broadcasts/me` | — | My active broadcast |
| PATCH | `/api/v1/broadcasts/:id/location` | 60/min | Update location (>50 m threshold to publish event) |
| POST | `/api/v1/broadcasts/:id/heartbeat` | 20/min | Extend 10-min TTL |
| DELETE | `/api/v1/broadcasts/:id` | — | Stop broadcast |

### Rooms

| Method | Path | Rate limit | Description |
|--------|------|-----------|-------------|
| POST | `/api/v1/rooms` | 3/min | Create room (stops your broadcast) |
| GET | `/api/v1/rooms/nearby` | — | Public WAITING rooms |
| GET | `/api/v1/rooms/me` | — | Room you are currently in |
| GET | `/api/v1/rooms/:id` | — | Room detail |
| POST | `/api/v1/rooms/:id/join` | 10/min | Join room (stops your broadcast) |
| POST | `/api/v1/rooms/:id/leave` | — | Leave room |
| DELETE | `/api/v1/rooms/:id` | — | Dissolve room (host only) |

### Friends & Social

| Method | Path | Rate limit | Description |
|--------|------|-----------|-------------|
| GET | `/api/v1/friends` | — | List accepted friends |
| GET | `/api/v1/friends/requests` | — | Pending incoming requests |
| POST | `/api/v1/friends/requests` | 20/hr | Send friend request |
| PUT | `/api/v1/friends/requests/:id/accept` | — | Accept |
| PUT | `/api/v1/friends/requests/:id/reject` | — | Reject |
| DELETE | `/api/v1/friends/:id` | — | Remove friend |
| POST | `/api/v1/users/:id/block` | — | Block user |
| DELETE | `/api/v1/users/:id/block` | — | Unblock user |

### WebSocket

```
GET /ws?token=<access_token>
```

#### Client → Server messages

```json
{"type": "update_location", "lat": 25.0330, "lng": 121.5654}
{"type": "ping"}
```

#### Server → Client messages

```json
{"type": "broadcast.started",  "data": { "broadcastId": "", "playerId": "", "displayName": "", "avatarUrl": "", "latitude": 0, "longitude": 0, "message": "", "distanceMeters": 0 }}
{"type": "broadcast.updated",  "data": { ... same as above ... }}
{"type": "broadcast.stopped",  "data": { ... same as above ... }}
{"type": "room.player_joined", "data": { "roomId": "", "eventType": "room.player_joined", "affectedPlayerId": "", "room": {...} }}
{"type": "room.player_left",   "data": { ... }}
{"type": "room.full",          "data": { ... }}
{"type": "room.dissolved",     "data": { ... }}
{"type": "friend.request",     "data": { "fromId": "", "requestId": "", "displayName": "" }}
{"type": "friend.accepted",    "data": { "friendId": "", "requestId": "" }}
{"type": "pong"}
```

---

## Architecture Decisions

### Why Gin + Gorilla WebSocket instead of GraphQL (as spec)?

The spec targets gqlgen for production. For the MVP backend sprint the team chose a REST + WebSocket approach because:
- Zero codegen step — faster iteration while the schema is still evolving
- QA can test every endpoint with standard HTTP tools (Postman, curl)
- GraphQL subscriptions and REST are semantically equivalent at this scale
- Migration path: add a GraphQL layer over the same service layer later

### Why MySQL instead of PostgreSQL?

Team's operational familiarity with MySQL. All business constraints that PostgreSQL enforces with `EXCLUDE USING gist(...)` are enforced at the service layer (with a DB unique index as a secondary safety net). This is acceptable for MVP traffic; revisit if race conditions appear under load.

Concretely:
- Single active broadcast per player → checked in `BroadcastService.Start` with `GetActiveByPlayerID` before insert
- Single active room seat per player → checked in `RoomService.Join` with `GetActiveSeatByPlayerID` before insert

### Redis key design

| Key | Type | TTL | Purpose |
|-----|------|-----|---------|
| `geo:broadcasts` | GeoSet | — (app-managed) | Active broadcast locations for GEORADIUS queries |
| `geo:online_users` | GeoSet | — (app-managed) | WebSocket-connected users' last-known location |
| `broadcast:ttl:{playerID}` | String | 10 min | Heartbeat sentinel; absence = broadcast expired |
| `friends:{userID}` | Set | 10 min | Friend ID cache; invalidated on add/remove |
| `blocked:{userID}` | Set | 1 hr | Block cache; invalidated on block/unblock |
| `jwt:blacklist:{jti}` | String | token remaining TTL | Revoked access tokens (logout) |
| `rate:{userID}:{action}:{window}` | String | 2× window | Fixed-window rate limiter counter |
| `mahjong:user:{userID}` | Pub/Sub channel | — | Personal channel for WebSocket event delivery |

### WebSocket fan-out strategy

Services publish events to `mahjong:user:{userID}` (one personal channel per user). The hub runs a **single** `PSubscribe("mahjong:user:*")` connection to Redis and routes messages to the appropriate in-process WebSocket connection. This avoids N individual subscribe connections for N connected users.

For broadcast events, `NotificationService` queries `geo:online_users` (GeoSearch) to find who is within 5 km, then publishes to each of their personal channels. Services decide *who* receives an event; the hub only does delivery.

### Location update threshold

Location updates are accepted at up to 60/min per the rate limit. A WebSocket fan-out event is only published when the player has moved **≥ 50 m** from the last stored position (Haversine distance check). This prevents unnecessary network traffic when a player is stationary.

### Account age restriction

New accounts (< 24 hours old) cannot start broadcasts, create rooms, or send friend requests. Checked in each service method via `user.CanBroadcast()`. This is a lightweight anti-spam measure for the Beta.

### JWT logout

Logout blacklists only the access token's JTI in Redis with a TTL equal to the token's remaining validity. The refresh token is not stored server-side; the client is responsible for discarding it. This keeps the JWT flow stateless except at logout.

### FCM notifications

`service/notification.go` contains a `fcmPush` stub that logs to stdout. Replace the stub body with `firebase.google.com/go/v4/messaging` calls when adding real push notification support. The service interface is already wired — no other files need to change.

---

## Error Codes

| Code | HTTP | Meaning |
|------|------|---------|
| `UNAUTHENTICATED` | 401 | Missing / expired / revoked token |
| `FORBIDDEN` | 403 | Authenticated but not authorised |
| `NOT_FOUND` | 404 | Resource does not exist |
| `VALIDATION_ERROR` | 400 | Request body failed binding/validation |
| `USER_ALREADY_EXISTS` | 409 | Username or email already taken |
| `INVALID_CREDENTIALS` | 401 | Wrong username or password |
| `BROADCAST_ALREADY_ACTIVE` | 409 | Player has an active broadcast |
| `BROADCAST_AGE_RESTRICTED` | 400 | Account < 24 h old |
| `ROOM_FULL` | 400 | Room has no open seats |
| `ROOM_NOT_JOINABLE` | 400 | Room is not in WAITING state |
| `ALREADY_IN_ROOM` | 409 | Player is already in another room |
| `FRIEND_LIMIT_EXCEEDED` | 400 | Reached 200-friend cap |
| `ALREADY_FRIEND` | 409 | Already friends |
| `FRIEND_REQUEST_EXISTS` | 409 | Pending request already sent |
| `ALREADY_BLOCKED` | 409 | Already blocking this user |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Unhandled server error |

---

## Deferred / Not in MVP

| Feature | Reason deferred |
|---------|----------------|
| OAuth (Apple / Google) | Needs App Store enrollment; use username+password for Beta |
| Real FCM push | Requires Firebase project setup; stub in place |
| TimescaleDB location history | MySQL used instead; batch-write location history table can be added in v1.1 |
| Redis Keyspace Notification listener | TTL expiry auto-stop of broadcasts; currently relies on heartbeat |
| Horizontal scaling (multiple app pods) | Single-server for Beta; the pub/sub architecture already supports it |
| `kickPlayer` / `transferHost` mutations | Spec defines them; excluded from MVP scope |
| `updateRoomSettings` mutation | Not needed for initial launch |
| Relay Cursor pagination for friend list | Simple array return for now |
| NATS JetStream migration | Publisher abstraction is in `NotificationService`; swap when needed |
| Location blurring for WAITING rooms | `utils.BlurCoordinates` helper exists; apply in `RoomHandler.GetByID` resolver when privacy policy is finalised |

---

## QA Test Checklist (P0 flows)

### Auth
- [ ] Register → login → get token → use token → logout → token rejected
- [ ] Refresh token flow
- [ ] Duplicate username / email returns `USER_ALREADY_EXISTS`
- [ ] Wrong password returns `INVALID_CREDENTIALS`

### Broadcast lifecycle
- [ ] New account (< 24 h) cannot start broadcast → `BROADCAST_AGE_RESTRICTED`
- [ ] Start broadcast → appears in `/nearby` for a second user within 5 km
- [ ] Second broadcast start returns `BROADCAST_ALREADY_ACTIVE`
- [ ] Update location → moved < 50 m → no WebSocket event emitted
- [ ] Update location → moved ≥ 50 m → `broadcast.updated` received over WebSocket
- [ ] Heartbeat extends TTL
- [ ] Stop broadcast → disappears from nearby list
- [ ] Joining a room auto-stops the player's broadcast

### Room lifecycle
- [ ] Create room → joins are possible (WAITING)
- [ ] 4th player joins → room becomes FULL → `room.full` event
- [ ] Host leaves → host transferred to oldest remaining member
- [ ] All players leave → room closes
- [ ] Dissolve by non-host → `FORBIDDEN`

### Social
- [ ] Send friend request → target receives WebSocket event
- [ ] Accept → both users appear in each other's `/friends` list
- [ ] Block user → friendship removed → blocked user cannot join same room

### WebSocket
- [ ] Connect with invalid token → connection refused
- [ ] `update_location` updates the online-users geo index (verify via nearby broadcast events)
- [ ] Disconnect → user removed from `geo:online_users`
