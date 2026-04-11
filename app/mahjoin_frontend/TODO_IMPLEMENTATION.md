# MahJoin Flutter Frontend TODO (Event-Complete)

## Milestone M1 - Architecture & Stability

Status: Completed (2026-04-11)

### 1) Build global event dispatcher
- Priority: P0
- Estimate: 0.5d
- Scope:
  - Create a single event routing layer for all WebSocket messages.
  - Normalize event payload parsing and unknown-event handling.
- Acceptance:
  - All WS events pass through one handler entry.
  - Unknown event types are safely ignored and logged.

### 2) Align WS type naming/docs
- Priority: P0
- Estimate: 0.25d
- Scope:
  - Update docs/comments to dot-notation event names used by backend.
- Acceptance:
  - No stale snake_case event examples remain in core WS docs.

### 3) Add auth redirect guard in router
- Priority: P0
- Estimate: 0.5d
- Scope:
  - Add redirect callback for logged-in / logged-out route protection.
- Acceptance:
  - Unauthenticated users cannot enter protected routes.
  - Logged-in users cannot get stuck on onboarding/login.

### 4) Add in-app notification center state
- Priority: P1
- Estimate: 0.75d
- Scope:
  - Central state for toast/banner/badge updates from events.
- Acceptance:
  - Event-driven notifications can be displayed from one place.

### 5) Error handling matrix (401/403/404/409/429/5xx)
- Priority: P1
- Estimate: 0.5d
- Scope:
  - Map API errors to user-friendly messages and actions.
- Acceptance:
  - No raw backend exception text shown in key flows.

## Milestone M2 - Full Event Coverage

Status: Completed (2026-04-11)

### 6) Implement broadcast.started
- Priority: P0
- Estimate: 0.5d
- Acceptance:
  - Marker/list appears or updates without duplicates.

### 7) Implement broadcast.updated
- Priority: P0
- Estimate: 0.5d
- Acceptance:
  - Marker/list location and distance update correctly.

### 8) Implement broadcast.stopped
- Priority: P0
- Estimate: 0.25d
- Acceptance:
  - Marker/list entry removed; selected detail closes if needed.

### 9) Implement room.created
- Priority: P0
- Estimate: 0.5d
- Acceptance:
  - New room appears on map and room list in real time.

### 10) Implement room.player_joined
- Priority: P0
- Estimate: 0.5d
- Acceptance:
  - Seat/member count refreshes in map/detail views.

### 11) Implement room.player_left
- Priority: P0
- Estimate: 0.5d
- Acceptance:
  - Seat/member updates and host-transfer reflects correctly.

### 12) Implement room.full flow
- Priority: P0
- Estimate: 1d
- Scope:
  - Add RoomFullPage and route /room/:id/full.
  - Navigate participants to full-room state UI.
- Acceptance:
  - In-room users get full-room transition reliably.

### 13) Implement room.dissolved flow
- Priority: P0
- Estimate: 0.5d
- Acceptance:
  - Users on dissolved room are redirected to map with feedback.

### 14) Implement friend.request realtime UI
- Priority: P1
- Estimate: 0.5d
- Acceptance:
  - Pending count and request list update via event.

### 15) Implement friend.accepted realtime UI
- Priority: P1
- Estimate: 0.5d
- Acceptance:
  - Friend list and pending state refresh immediately.

### 16) Add ping/pong connection health indicator
- Priority: P2
- Estimate: 0.25d
- Acceptance:
  - UI shows connection health and recent heartbeat result.

## Milestone M3 - Feature Completion

Status: Completed (2026-04-11)

### 17) Map long-press to create room
- Priority: P1
- Estimate: 0.5d
- Acceptance:
  - Long-press opens create-room flow with location prefilled.

### 18) Complete CreateRoom form fields
- Priority: P1
- Estimate: 0.5d
- Scope:
  - Add placeName, gameRule, isPublic editing.
- Acceptance:
  - Payload matches backend contract and user input.

### 19) Wire all placeholder profile actions
- Priority: P1
- Estimate: 0.75d
- Acceptance:
  - No no-op onTap remains in profile menu.

### 20) Complete room lifecycle state cleanup
- Priority: P1
- Estimate: 0.5d
- Acceptance:
  - Join/leave/dissolve transitions never leave stale UI state.

### 21) Complete social lifecycle consistency
- Priority: P1
- Estimate: 0.75d
- Acceptance:
  - Send/accept/reject/remove/block/unblock always sync local state.

## Milestone M4 - Quality & Release

Status: Completed (2026-04-11)

### 22) Resolve REST-vs-event race conditions
- Priority: P1
- Estimate: 0.75d
- Acceptance:
  - Idempotent upsert/remove strategy avoids flicker and stale state.

### 23) Mock-mode safety boundary
- Priority: P1
- Estimate: 0.5d
- Acceptance:
  - Production runs cannot accidentally use mock data paths.

### 24) Event integration tests
- Priority: P1
- Estimate: 1d
- Acceptance:
  - Core event types covered with repeatable test setup.

### 25) Session/header persistence tests
- Priority: P0
- Estimate: 0.75d
- Acceptance:
  - userId restoration and X-User-ID header behavior verified.

### 26) E2E smoke checklist for iOS real device
- Priority: P1
- Estimate: 0.5d
- Acceptance:
  - Login, map, room, friends, and WS smoke pass on device 0000.

### 27) Docs sync (README + DEV_GUIDE)
- Priority: P2
- Estimate: 0.5d
- Acceptance:
  - Docs reflect actual routes, events, and implemented flows.

---

## Suggested execution order
1. M1 first (stability baseline)
2. M2 next (event-complete core)
3. M3 then (UX/product completion)
4. M4 last (quality and release hardening)

## Definition of Done (global)
- No placeholder action remains in core flows.
- All backend event types have frontend handling or explicit ignore policy.
- Protected routes enforce auth.
- Room and friend states converge correctly after reconnect.
- Smoke tests pass on iOS real device and simulator.
