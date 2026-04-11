# iOS Smoke Checklist (Device 0000)

Target device: 00008110-000A7CC01E81401E

## Launch
- Build and run:
  - `flutter run -d 00008110-000A7CC01E81401E --dart-define=MOCK_MODE=false --dart-define=API_BASE_URL=http://168.138.210.65:8080`
- Verify app reaches onboarding/login without crash.

## Authentication
- Register a new account.
- Sign out and sign in again with same account.
- Kill app, relaunch, verify session restore works (still logged in).

## Map + Broadcast
- Confirm map loads nearby rooms/players.
- Start broadcast from FAB.
- Verify your marker appears and WS health chip shows `WS: ok`.
- Move physically/simulate location updates and verify no crash.
- Stop broadcast and verify state returns to idle.

## Room Lifecycle
- Long-press map to open create-room sheet with prefilled coordinates.
- Create room with `placeName`, `gameRule`, and `isPublic` values.
- Enter room detail page.
- Join/leave flow from another account if available.
- Trigger `room.full` and verify navigation to `/room/:id/full`.
- Trigger room dissolve and verify redirect to map.

## Friends + Social
- Send friend request by username.
- Verify pending badge/list updates in realtime.
- Accept/reject request from another account.
- Verify friend list refreshes and no stale entries remain.
- Remove friend, block, unblock, and verify list consistency.

## Realtime Reliability
- Put app background for 30-60 seconds and return.
- Verify WS reconnects and health chip is not stale.
- Verify no duplicate markers after reconnect.

## Error UX
- Temporarily disconnect network.
- Verify user-facing error messages are readable (not raw exceptions).
- Reconnect network and retry flows.

## Release Safety Guard
- Confirm release builds do not allow `MOCK_MODE=true` unless
  `ALLOW_MOCK_IN_RELEASE=true` is explicitly set.

## Pass Criteria
- No crash in full flow.
- Core flows complete with expected navigation.
- Realtime events update UI exactly once (no flicker/duplicates).
- Session persistence and auth guard behavior are correct.
