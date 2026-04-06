# 麻將找人定位系統 — Flutter 前端團隊討論記錄 & MVP Roadmap

> **文件性質**：Flutter Frontend Architecture Discussion & MVP Roadmap
> **參與者**：
> - Chen（Senior Flutter，架構主導）
> - Amy（Flutter Mid-level，地圖與定位）
> - David（Flutter Mid-level，狀態管理與 GraphQL）
> - Nina（Flutter Junior，UI/UX 實作）
> **旁聽**：Alex（Backend Senior，API 設計對齊）
> **日期**：2026-03-28
> **版本**：v1.0

---

## 目錄

1. [技術對齊：後端 API 確認](#1-技術對齊後端-api-確認)
2. [Flutter 技術棧決策](#2-flutter-技術棧決策)
3. [應用程式架構設計](#3-應用程式架構設計)
4. [核心模組設計](#4-核心模組設計)
5. [地圖與定位設計](#5-地圖與定位設計)
6. [WebSocket 與 Subscription 管理](#6-websocket-與-subscription-管理)
7. [離線與重連策略](#7-離線與重連策略)
8. [UI/UX 架構設計](#8-uiux-架構設計)
9. [效能設計](#9-效能設計)
10. [測試策略](#10-測試策略)
11. [MVP Roadmap 與任務分配](#11-mvp-roadmap-與任務分配)
12. [React 19 網頁端評估](#12-react-19-網頁端評估)
13. [開放問題清單](#13-開放問題清單)

---

## 1. 技術對齊：後端 API 確認

### 1.1 後端給前端的確認事項

---

**Alex**：在你們開始設計之前，我先把後端已確定的東西告訴你們，避免之後要改。

第一，GraphQL 的 Subscription 用 `graphql-ws` protocol，不是舊的 `subscriptions-transport-ws`。Ferry 預設支援兩種，但要在設定裡明確指定新版。

第二，WebSocket 的認證是 `connection_init` message 帶 JWT，不是 URL query string。你們的 WebSocket link 要在建立連線後第一個 message 送 auth payload。

第三，位置座標的格式：所有 API 都是 `{ lat: Float, lng: Float }`，沒有例外。Flutter 的 `LatLng` 要注意 Geolocator 給的是 `latitude/longitude`，要 mapping 清楚。

第四，Error code 已定義好（見規格書 Section 5.4），所有業務錯誤都在 `extensions.code` 裡，不是 HTTP status code。你們的 error handling 要解析 GraphQL error extensions。

**Chen**：收到。有幾個我想確認的地方。

Room 的 `location` 欄位，規格書說 WAITING 時是模糊座標，FULL 後是精確座標。這個是 server 端 Resolver 決定的，client 不需要判斷，對嗎？

**Alex**：對，完全 server 端決定。你們拿到的座標就是應該顯示的座標，不需要 client 再做任何處理。

**Chen**：`nearbyPlayerUpdates` Subscription 回傳的 `priority` 欄位（好友=1，陌生人=10），我們計劃用這個做 UI 分層：好友 Marker 在頂層永遠顯示，陌生人 Marker 在底層可以 cluster。這個設計你有問題嗎？

**Alex**：完全沒問題，`priority` 欄位就是為這個設計的。補充一點：`isFriend` 是 boolean，比 `priority` 更直覺，你們可以直接用 `isFriend` 決定 UI，用 `priority` 排序列表。

**David**：Ferry 的 code generation 需要你們的 schema 文件。什麼時候可以給我們一份穩定的 schema？

**Alex**：Phase 0 結束（Week 1）我給你們一份 `schema.graphql`，之後有改動我會通知你們，但核心型別（Room、Broadcast、User）不會有 breaking change，只會加欄位。

---

### 1.2 前端需要後端提供的清單

| 項目 | 負責人 | 截止 |
|------|--------|------|
| `schema.graphql` 穩定版 | Alex | Week 1 結束 |
| Local dev URL（docker-compose）| Ben | Week 1 |
| Apple/Google OAuth Client ID（測試用）| Alex | Week 1 |
| FCM Server Key（Notification 測試）| Alex | Week 6 |
| Staging URL + 測試帳號 | Ben | Week 10 |

---

## 2. Flutter 技術棧決策

### 2.1 技術選型討論

---

**Chen**：我來說我對技術棧的選擇，然後大家討論有沒有異議。

**Amy**：地圖的部分我想先說。上次專案用 `google_maps_flutter`，在 iOS 上大量 Marker 更新時 frame rate 掉到 30fps 以下。我比較傾向用 `flutter_map`，它是純 Dart 實作，Marker 更新不走 platform channel，效能更好。

**Chen**：同意 Amy 的觀察。`flutter_map` 加 `OpenStreetMap` 還有個優點是不需要 API key，減少一個依賴。唯一的缺點是 OSM 的 tile 在偏遠地區品質比 Google Maps 差，但台北市完全沒問題。

**David**：GraphQL client 的部分，我評估過 `graphql_flutter`、`ferry`、`artemis`。我的結論是用 `ferry`。

原因一：`ferry` 的 Subscription Stream 在 WebSocket 斷線重連後能自動 re-subscribe，`graphql_flutter` 需要自己處理。

原因二：`ferry` 的 code generation 和 Riverpod 整合是最自然的——generated 的 Request class 可以直接傳給 `StreamProvider`，型別安全。

原因三：`ferry` 的 `graphql_ws` protocol 支援是一等公民，而 Alex 說後端用的是新版 protocol。

**Nina**：動畫套件我想用 `flutter_animate`，它的 API 比 `animations` 套件簡潔很多。好友上線的彈跳效果、Room 滿員的慶祝動畫，用 `flutter_animate` 寫起來很快。

**Chen**：沒問題。Router 的部分我選 `go_router`，不用 Navigator 2.0 原生 API，因為我們有 deep link 需求（Room 邀請連結）。

---

### 2.2 技術棧清單（確認版）

| 類別 | 套件 | 版本目標 | 選擇理由 |
|------|------|----------|----------|
| **GraphQL** | `ferry` | ^0.15 | graphql-ws 支援、Riverpod 整合、auto reconnect |
| **狀態管理** | `flutter_riverpod` | ^2.6 | StreamProvider 接 Subscription、autoDispose 清理 |
| **Code Gen** | `riverpod_generator` + `ferry_generator` | latest | 減少手寫 boilerplate |
| **路由** | `go_router` | ^14 | Deep link、nested routing、型別安全 |
| **地圖** | `flutter_map` | ^6 | 純 Dart、效能好、無 API key |
| **地圖 Tiles** | `flutter_map_cache` | ^1 | Tile 本地快取，離線可用 |
| **定位** | `geolocator` | ^11 | iOS/Android background mode、跨平台 |
| **本地儲存** | `hive_ce` | ^2 | 快取好友列表、用戶資料（hive_ce 是維護版） |
| **推播通知** | `firebase_messaging` | ^15 | FCM 標準整合 |
| **錯誤追蹤** | `sentry_flutter` | ^8 | Crash 自動上報 |
| **Analytics** | `firebase_analytics` | ^11 | 用戶行為埋點 |
| **圖片快取** | `cached_network_image` | ^3 | Avatar |
| **動畫** | `flutter_animate` | ^4 | 好友上線動畫、Room 滿員動畫 |
| **安全儲存** | `flutter_secure_storage` | ^9 | JWT 存入 Keychain/Keystore |
| **OAuth** | `sign_in_with_apple` + `google_sign_in` | latest | |
| **HTTP** | `dio` | ^5 | 非 GraphQL 的 REST 呼叫（頭像上傳等）|
| **依賴注入** | Riverpod（Provider 即 DI）| — | 不額外引入 get_it |
| **測試** | `mocktail` + `alchemist` | latest | Mock + Golden test |

---

### 2.3 明確不採用的套件

| 套件 | 不採用原因 |
|------|----------|
| `google_maps_flutter` | Platform channel 大量 Marker 效能問題 |
| `graphql_flutter` | Subscription reconnect 不穩定 |
| `get_it` | Riverpod 已提供 DI，不需要兩套 |
| `bloc` | StreamProvider + AsyncNotifier 已夠用，BLoC 過重 |
| `provider` | Riverpod 的前身，不混用 |
| `get` / `getx` | 過度整合，難以測試 |

---

## 3. 應用程式架構設計

### 3.1 分層架構

---

**Chen**：我們採用和後端 DDD 對齊的分層思想，但名稱和 Flutter 慣例對齊：

```
Presentation Layer（Widgets + Pages）
    ↑ 監聽
State Layer（Riverpod Providers + Notifiers）
    ↑ 呼叫
Domain Layer（Use Cases + Entities）
    ↑ 依賴
Data Layer（Repository + Remote/Local Data Source）
```

**David**：這個架構和 Riverpod 的最佳實踐完全吻合。`Provider` 住在 State Layer，負責協調 Domain 和 Presentation。Widgets 只做 `ref.watch`，不含任何業務邏輯。

**Amy**：地圖相關的邏輯要特別注意。Marker 的計算和排序屬於 State Layer（`nearbyPlayersMapProvider`），Widget 只負責把 Marker list 傳給 `FlutterMap`，不在 Widget 裡做任何篩選或排序。

**Nina**：UI Component 的部分，我想建立一個 Design System（`lib/core/design/`），把所有顏色、字型、間距常數集中管理。這樣我改一個顏色不需要改 50 個檔案。

**Chen**：很好，加進架構裡。

---

### 3.2 目錄結構

```
lib/
│
├── main.dart                          ← FX 風格的 ProviderScope + GoRouter 初始化
│
├── core/                              ← 跨 Feature 共用
│   ├── design/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   └── app_theme.dart
│   ├── network/
│   │   ├── graphql_client.dart        ← Ferry client 初始化（含 auth link）
│   │   ├── websocket_link.dart        ← graphql-ws connection_init 設定
│   │   └── auth_link.dart             ← 為每個 Request 加入 Authorization header
│   ├── storage/
│   │   ├── secure_storage.dart        ← JWT token（Keychain/Keystore）
│   │   └── hive_storage.dart          ← 好友列表、用戶資料快取
│   ├── location/
│   │   ├── location_service.dart      ← Geolocator wrapper
│   │   └── location_provider.dart     ← Riverpod Provider
│   ├── error/
│   │   ├── app_exception.dart         ← GraphQL error → App exception
│   │   └── error_handler.dart
│   └── router/
│       ├── app_router.dart            ← GoRouter 設定
│       └── routes.dart                ← Route constants
│
├── features/                          ← 按功能模組切分
│   │
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── token_storage.dart
│   │   ├── domain/
│   │   │   └── auth_state.dart        ← AuthState（authenticated/unauthenticated）
│   │   ├── presentation/
│   │   │   ├── login_page.dart
│   │   │   └── widgets/
│   │   │       ├── apple_sign_in_button.dart
│   │   │       └── google_sign_in_button.dart
│   │   └── auth_provider.dart         ← AuthNotifier
│   │
│   ├── onboarding/
│   │   ├── presentation/
│   │   │   ├── onboarding_page.dart
│   │   │   └── widgets/
│   │   │       └── onboarding_slide.dart
│   │   └── onboarding_provider.dart   ← 記錄是否看過 Onboarding
│   │
│   ├── map/                           ← 主地圖（核心功能）
│   │   ├── data/
│   │   │   └── broadcast_repository.dart
│   │   ├── domain/
│   │   │   ├── player_on_map.dart     ← UI Model（非 GraphQL generated model）
│   │   │   └── broadcast_state.dart
│   │   ├── presentation/
│   │   │   ├── map_page.dart          ← 主地圖頁面
│   │   │   └── widgets/
│   │   │       ├── player_map.dart    ← FlutterMap + Marker 層
│   │   │       ├── friend_marker.dart ← 好友 Marker（有動畫）
│   │   │       ├── stranger_marker.dart
│   │   │       ├── broadcast_fab.dart ← 開始/停止廣播 FAB
│   │   │       ├── empty_state_overlay.dart
│   │   │       └── player_info_sheet.dart  ← 點擊 Marker 後的底部 Sheet
│   │   ├── map_provider.dart          ← nearbyPlayersMapProvider
│   │   └── broadcast_provider.dart   ← BroadcastNotifier
│   │
│   ├── room/
│   │   ├── data/
│   │   │   └── room_repository.dart
│   │   ├── domain/
│   │   │   └── room_model.dart
│   │   ├── presentation/
│   │   │   ├── nearby_rooms_page.dart
│   │   │   ├── room_detail_page.dart
│   │   │   ├── create_room_page.dart
│   │   │   └── room_full_page.dart    ← 4 人到齊後的導引頁面
│   │   │   └── widgets/
│   │   │       ├── seat_card.dart
│   │   │       ├── room_card.dart
│   │   │       └── game_rule_selector.dart
│   │   └── room_provider.dart
│   │
│   ├── friends/
│   │   ├── data/
│   │   │   └── social_repository.dart
│   │   ├── presentation/
│   │   │   ├── friends_page.dart
│   │   │   ├── friend_requests_page.dart
│   │   │   └── widgets/
│   │   │       ├── friend_card.dart
│   │   │       └── active_friend_card.dart  ← 正在廣播的好友
│   │   └── friends_provider.dart
│   │
│   ├── profile/
│   │   ├── presentation/
│   │   │   ├── profile_page.dart
│   │   │   └── edit_profile_page.dart
│   │   └── profile_provider.dart
│   │
│   └── notification/
│       ├── fcm_handler.dart           ← FCM 訊息處理
│       └── notification_provider.dart
│
├── graphql/                           ← Ferry code generation
│   ├── operations/                    ← .graphql 操作文件（手寫）
│   │   ├── auth.graphql
│   │   ├── broadcast.graphql
│   │   ├── room.graphql
│   │   └── social.graphql
│   └── schema.graphql                 ← 從後端同步（不手改）
│
└── generated/                         ← ferry_generator 產生（不手改）
    └── graphql/
        ├── auth.data.gql.dart
        ├── broadcast.data.gql.dart
        └── ...
```

---

### 3.3 Feature Module 的邊界原則

---

**Chen**：幾個 feature module 之間的規則：

```
原則 1：Feature 之間不直接 import 對方的 Widget
  ✅ map feature 透過 GoRouter 跳到 room feature 的頁面
  ❌ map feature import room feature 的 RoomDetailPage

原則 2：Feature 之間透過 Provider 共享狀態
  ✅ room feature 讀 currentLocationProvider（在 core/location）
  ❌ room feature 直接呼叫 map feature 的 locationService

原則 3：Domain Model 不等於 GraphQL Generated Model
  GraphQL generated：GNearbyBroadcastsData_nearbyBroadcasts（冗長的 generated 名稱）
  UI Model：PlayerOnMap（乾淨的 domain model，只含 UI 需要的欄位）
  Repository 負責把 generated model 轉成 domain model
```

**Nina**：這個規則對我影響最大。我之前習慣直接用 generated model 做 UI，但名字太長了，而且 generated model 改了 UI 也要跟著改。

**David**：對，Repository 的職責就是隔離這層。GraphQL schema 改了，只需要改 Repository 裡的 mapping 函式，UI 不受影響。

---

## 4. 核心模組設計

### 4.1 網路層（GraphQL Client）

---

**David**：Ferry client 的初始化有幾個重要設計決策。

**關鍵 1：Auth Link 的 Token 注入**

Ferry 的 Link 是鏈式的，Auth Link 在請求發出前加入 Authorization header。Token 從 `flutter_secure_storage` 讀取，不是 hardcode。

**關鍵 2：WebSocket Link 的 connection_init**

後端要求在 `connection_init` message 的 payload 帶 JWT，Ferry 的 `GqlWsLink` 有 `initialPayload` 參數可以動態注入。每次 WebSocket 連線建立時，讀取最新的 access token。這樣 token refresh 後，WebSocket reconnect 時會用新的 token。

**關鍵 3：Link 的分流**

```
GraphQL Operation 分流：

  Query / Mutation → HttpLink（帶 Authorization header）
  Subscription    → GqlWsLink（帶 connection_init JWT）

  用 SplitLink 根據 operation type 決定走哪條 link
```

**關鍵 4：Token Refresh 的處理**

Access token 15 分鐘過期。Ferry 的 Auth Link 要實作 token refresh 邏輯：收到 UNAUTHENTICATED error 時，自動用 refresh token 換新的 access token，然後 retry 原本的 request。

---

**Amy**：WebSocket 的 reconnect 邏輯怎麼設計？

**David**：Ferry 的 `GqlWsLink` 有內建 reconnect，但我們要控制：

```
Reconnect 策略：
  斷線後立即 retry 1 次
  失敗：等 2s retry
  失敗：等 4s retry
  失敗：等 8s... 最大 60s（exponential backoff）

Reconnect 成功後的動作：
  1. 自動 re-subscribe（Ferry 內建）
  2. 主動 refetch nearbyBroadcasts（補齊斷線期間的 snapshot）
  3. 顯示「已重新連線」toast（1.5 秒後消失）

這個邏輯住在 connectionManagerProvider，所有 feature 都可以 watch 連線狀態
```

---

### 4.2 狀態管理設計（Riverpod）

---

**David**：Riverpod 的 Provider 分層：

**Infrastructure Providers（core/）**：

```
graphQLClientProvider       ← Ferry client（Singleton）
currentLocationProvider     ← Stream<Position>，App 生命週期內持續
secureStorageProvider       ← flutter_secure_storage
hiveBoxProvider             ← Hive box（不同 box 用不同 key）
connectionStateProvider     ← WebSocket 連線狀態（connected/reconnecting/offline）
```

**Feature Providers（features/{name}/）**：

```
Auth：
  authStateProvider           ← authenticated/unauthenticated/loading
  currentUserProvider         ← 當前登入用戶資料

Map/Broadcast：
  nearbyBroadcastsProvider    ← Subscription Stream（雙 channel 合併後的 PlayerUpdate）
  nearbyPlayersMapProvider    ← 從 nearbyBroadcastsProvider 轉換的 Marker 列表
  myActiveBroadcastProvider   ← 我的當前廣播狀態
  broadcastNotifier           ← startBroadcast / stopBroadcast / updateLocation

Room：
  nearbyRoomsProvider         ← 附近 WAITING Room 列表
  currentRoomProvider         ← 我目前所在的 Room
  roomDetailProvider(id)      ← 特定 Room 詳情 + roomUpdated Subscription
  roomNotifier                ← createRoom / joinRoom / leaveRoom

Friends：
  friendsProvider             ← 好友列表（Hive cache + GraphQL 混合）
  activeFriendBroadcastsProvider ← 正在廣播的好友列表
  friendRequestsProvider      ← 待處理好友請求
```

---

**Nina**：我想確認一件事。地圖頁面同時要顯示廣播和 Room，它們是兩個不同的 Provider，Widget 怎麼監聽？

**Chen**：用 `Consumer` 或 `ref.watch` 同時監聽多個 Provider。Widget rebuild 的觸發條件是任一 Provider 有變化。地圖 Widget 應該只監聽「地圖上需要顯示的資料」：

```
MapPage watches：
  nearbyPlayersMapProvider   → Marker 列表（Player）
  nearbyRoomsProvider        → Marker 列表（Room）
  myActiveBroadcastProvider  → 顯示「廣播中」狀態
  connectionStateProvider    → 顯示連線狀態 banner
```

**Amy**：我還有個問題。`currentLocationProvider` 是 `Stream<Position>`，每 5 秒一個新值。地圖 Widget 要跟著移動中心嗎？

**Chen**：不自動移動，只在 App 剛開啟時 fly to 用戶位置一次。之後用戶可以自由拖動地圖，我們不干涉。如果強制跟隨用戶位置，拖動地圖的體驗很差。

---

### 4.3 Error Handling 設計

---

**David**：GraphQL error 的統一處理：

```
Error 分層：

  Layer 1：Network Error
    → 無法連線，顯示「連線失敗，請檢查網路」banner

  Layer 2：GraphQL Error（有 extensions.code）
    → 解析 code，轉換成 App 的 AppException
    → 由各 Notifier 決定如何呈現

  Layer 3：Validation Error（400 範圍）
    → 顯示 SnackBar 或 inline error message

Error Code 對應 UI 行為：

  UNAUTHENTICATED    → 登出，跳轉登入頁（全域處理）
  ROOM_FULL          → SnackBar：「這個 Room 已經滿了」
  ALREADY_IN_ROOM    → SnackBar：「你已經在另一個 Room 了，請先離開」
  BROADCAST_AGE_RESTRICTED → Dialog：「帳號建立未滿 24 小時，明天再來！」倒計時顯示
  RATE_LIMITED       → SnackBar：「操作太頻繁，請稍後再試」，disable 按鈕 30 秒
  FRIEND_LIMIT_EXCEEDED → SnackBar：「好友上限 200 人，請先移除部分好友」
  INTERNAL_ERROR     → SnackBar：「系統錯誤，我們已記錄，請稍後再試」+ Sentry 上報
```

**Nina**：`UNAUTHENTICATED` 是全域的，不是每個頁面都要處理嗎？

**David**：對，全域 error listener 在 `App` Widget 的最頂層，監聽 `authStateProvider`。任何 Provider 收到 `UNAUTHENTICATED` 就把 authState 設成 `unauthenticated`，Router 的 redirect 邏輯自動跳轉登入頁。

---

## 5. 地圖與定位設計

### 5.1 FlutterMap 架構

---

**Amy**：地圖的 Layer 設計是效能的關鍵。

```
FlutterMap 的 Layer 堆疊（由下到上）：

Layer 1：TileLayer（OpenStreetMap）
  → 地圖底圖，flutter_map_cache 本地快取

Layer 2：RoomMarkerLayer
  → 附近 WAITING Room 的 pin
  → Marker 顯示 Room 名稱 + 座位數（1/4、2/4 等）
  → Tap → 開啟 RoomDetailSheet

Layer 3：StrangerClusterLayer（MarkerClusterLayer）
  → 陌生人廣播 Marker
  → zoom < 14：自動 cluster（顯示人數）
  → zoom ≥ 14：顯示個人頭像
  → 使用 flutter_map_marker_cluster 套件

Layer 4：FriendMarkerLayer
  → 好友廣播 Marker（永遠顯示，不 cluster）
  → 頂層，不被陌生人 Marker 遮擋
  → 有上線動畫（flutter_animate）

Layer 5：MyLocationLayer
  → 自己的位置（不同樣式，更大的圓點）
  → 廣播中時顯示漸層圈圈（代表廣播範圍）
```

**Chen**：Layer 5 的廣播範圍圈圈要注意：半徑 5km 在不同 zoom level 下的像素大小不同，要用 `metersToPixels` 換算，不能 hardcode pixel 大小。

**Nina**：Room Marker 和 Broadcast Marker 的樣式我在設計系統裡定好，需要你們確認 Marker 的大小規格。

**Amy**：Friend Marker：60×80px，顯示頭像 + 名字。Stranger Marker：40px 圓形頭像（無名字）。Room Marker：自定義 Widget，顯示 icon + 座位狀態。

---

### 5.2 定位策略

---

**Amy**：iOS 和 Android 的背景定位差異很大，要分開討論。

**iOS 背景定位**：

```
問題：iOS 在 App 背景時，系統嚴格限制定位頻率，最慢可能 15 分鐘才更新一次。

策略：
  Foreground：geolocator 高精度，每 5 秒或移動 30m（取先到者）
  Background：Significant Location Change（移動約 500m 觸發）+ BGAppRefreshTask

App Store 審查重點：
  Info.plist 必須有：
    NSLocationAlwaysAndWhenInUseUsageDescription
    NSLocationWhenInUseUsageDescription
  說明文字必須明確：「用於廣播你的位置給附近的麻將玩家」
  → 不能只寫「用於定位服務」，Apple 會退件
```

**Android 背景定位**：

```
Android 10+：
  需要 ACCESS_BACKGROUND_LOCATION 權限
  必須在獨立的 Permission Dialog 中說明（不能和前景權限合併）

Android 12+：
  Foreground Service 需要 FOREGROUND_SERVICE_LOCATION 宣告
  使用 WorkManager 替代 Foreground Service（更節能）

電量優化考量：
  靜止不動時：Significant Change threshold 50m，不送 updateLocation API
  進入 Room 後：停止定位（廣播已停，不需要更新位置）
  廣播停止後：降為低精度（每 5 分鐘，只更新地圖上自己的 pin）
```

**Chen**：背景定位的「假性存在」問題，和後端確認的結果是：TTL 10 分鐘，最壞情況廣播假性存在 10 分鐘。我們的 UI 要反映這一點——每個廣播 Marker 要顯示「最後更新時間」（幾分鐘前），讓用戶知道這個位置不一定是即時的。

**Amy**：「最後更新 3 分鐘前」這樣的格式嗎？

**Chen**：對。Marker 上不顯示（太小），但點擊 Marker 後的 PlayerInfoSheet 裡顯示。

---

### 5.3 定位權限請求策略

---

```
權限請求時機（不在 App 啟動時立刻要）：

Step 1：App 啟動 → 不要求任何權限

Step 2：用戶點「開始廣播」→ 觸發「使用中」定位權限請求
  說明：「開始廣播需要取得你的位置，讓附近的玩家能找到你」

Step 3：用戶點「開始廣播」且 App 在背景 → 觸發「永遠允許」權限說明
  說明：「允許背景定位，即使 App 在背景也能維持廣播」
  注意：不強制要求，用戶可以只給「使用中」，廣播功能仍可使用

Step 4：用戶拒絕 → 顯示說明 Dialog，提供「去設定」按鈕
  不反覆騷擾：被拒絕後，下一次觸發至少間隔 7 天
```

---

## 6. WebSocket 與 Subscription 管理

### 6.1 Subscription 生命週期

---

**David**：Riverpod 的 `autoDispose` 機制是管理 Subscription 生命週期的核心工具。

```
Subscription 的啟動和停止：

  地圖頁面進入 → nearbyBroadcastsProvider 的 StreamProvider 啟動
                → Ferry 建立 GraphQL Subscription（送 subscribe message）
                → Server 開始 push PlayerUpdate

  地圖頁面離開 → StreamProvider.autoDispose 觸發
                → Ferry 送 complete message（取消 Subscription）
                → Server 端的 Subscription goroutine 收到 ctx.Done() 退出
                → Redis Pub/Sub Unsubscribe

  Room 詳情頁進入 → roomDetailProvider(roomID) 啟動
                  → roomUpdated Subscription 啟動

  Room 詳情頁離開 → autoDispose，Subscription 停止
```

**Amy**：如果用戶在地圖頁和 Room 頁之間快速切換呢？autoDispose 會頻繁啟停 Subscription？

**David**：Riverpod 有 `keepAlive()` 可以防止這個。對於核心的 `nearbyBroadcastsProvider`，我計劃在 App 進入地圖後 keep alive 直到 App 進背景，而不是每次離開地圖頁就停止。這樣從 Room 頁返回地圖時，Subscription 不需要重新建立。

**Chen**：同意。`keepAlive` 的觸發條件：

```
keepAlive = true：  App 在前景 + 用戶有 ACTIVE 廣播
keepAlive = false：App 進背景 或 廣播停止
```

---

### 6.2 連線狀態 UI 反饋

---

**Nina**：用戶需要知道現在是否連線，這個 UI 怎麼設計？

**Chen**：

```
連線狀態的 UI 呈現：

  Connected（正常）：無 UI，不打擾用戶

  Reconnecting（重連中）：
    頂部出現一個細 banner：「連線中斷，正在重新連線...」
    顯示動畫 loading indicator
    背景顯示淡化的地圖（表示資料可能不是最新）

  Reconnected（重連成功）：
    Banner 變成「已重新連線」（綠色）
    1.5 秒後自動消失
    自動 refetch nearbyBroadcasts

  Offline（無網路）：
    Banner：「目前離線，部分功能不可用」
    地圖顯示快取的 Tile，Marker 顯示最後已知位置（灰色）
    廣播 FAB 變成 disabled 狀態
```

---

## 7. 離線與重連策略

### 7.1 Hive 快取策略

---

**David**：

```
快取什麼：
  好友列表（friendsBox）
    → TTL：不設 TTL，以 GraphQL 拉到的資料為準（refresh 時更新）
    → 離線時：顯示快取的好友列表，標記「可能不是最新」

  當前用戶資料（userBox）
    → 用於離線時顯示 Profile，避免閃白
    → App 啟動時先顯示快取，背景更新後再刷新

  Onboarding 完成狀態（settingsBox）
    → bool，永不過期

不快取什麼：
  廣播資料（即時性，快取無意義）
  Room 資料（狀態變化太快，快取可能導致誤判）
  位置歷史（量太大，不在 client 端儲存）
```

---

### 7.2 重連後的資料補齊

---

**Amy**：WebSocket 重連成功後，Subscription 會自動重新訂閱，但斷線期間的事件怎麼補齊？

**David**：

```
補齊策略（Snapshot + Stream）：

  Step 1：WebSocket 重連成功
  Step 2：re-subscribe Subscription（Ferry 自動）
  Step 3：主動 refetch nearbyBroadcasts Query（補齊 snapshot）
          → 用 ref.invalidate(nearbyBroadcastsProvider) 強制重新拉
  Step 4：UI 從 snapshot 開始更新，後續靠 Subscription 維持即時性

  為什麼這樣設計：
    Subscription 只接收「從訂閱時間點之後」的事件
    斷線期間的事件（有人開始或停止廣播）不會被 push
    必須用 Query 拿當前的 snapshot，才能保證資料完整
```

---

## 8. UI/UX 架構設計

### 8.1 Navigation 架構

---

**Nina**：GoRouter 的路由設計：

```
路由設計：

  /onboarding              ← OnboardingPage（只有第一次啟動）
  /login                   ← LoginPage
  /                        ← MainShell（BottomNavigationBar）
    /map                   ← MapPage（主地圖，預設 Tab）
    /friends               ← FriendsPage
    /profile               ← ProfilePage
  /room/create             ← CreateRoomPage（全螢幕）
  /room/:id                ← RoomDetailPage（全螢幕）
  /room/:id/full           ← RoomFullPage（4 人到齊後）

Deep Link（Room 邀請）：
  mahjong://room/:id       → 直接開啟 RoomDetailPage
  https://mahjong.io/room/:id → 網頁版（未來）

Router Guard（redirect）：
  未登入 → 任何 protected 路由 → redirect to /login
  已完成 Onboarding → /onboarding → redirect to /map
  沒有 ACTIVE 廣播 → /room/create → 不攔截（可以先看房間）
```

---

### 8.2 BottomNavigationBar 的 State 保留

---

**Nina**：切換 Tab 時，每個 Tab 的 scroll 位置和資料要保留嗎？

**Chen**：要。用 `IndexedStack`，不用 `PageView`。`IndexedStack` 讓每個 Tab 的 Widget tree 常駐記憶體，切換時不重建，scroll 位置保留。

```
MainShell 設計：
  IndexedStack（保留每個 Tab 的 Widget tree）
    ├── MapPage（Tab 0）
    ├── FriendsPage（Tab 1）
    └── ProfilePage（Tab 2）

  Bottom NavBar：
    🗺 地圖（Tab 0）
    👥 好友（Tab 1，有好友請求數的 badge）
    👤 我（Tab 2）
```

---

### 8.3 關鍵頁面設計原則

---

**Nina**：

**MapPage（主地圖）**：

```
Layout：
  FlutterMap（全螢幕，包含所有 Layer）
  FAB（右下）：開始廣播 / 停止廣播
  連線狀態 Banner（頂部）
  Empty State Overlay（附近沒人時）
  我的位置按鈕（右下，在 FAB 上方）

互動：
  長按地圖空白處 → 顯示「在此建立 Room」選項
  點擊 Player Marker → 底部 Sheet（PlayerInfoSheet）
  點擊 Room Marker → 底部 Sheet（RoomInfoSheet）
  點擊廣播 FAB → 如果未廣播：確認 Dialog → startBroadcast
               → 如果廣播中：確認 Dialog → stopBroadcast
```

**RoomDetailPage**：

```
Layout：
  4 個座位 Widget（2×2 grid）
  Host 標記（皇冠 icon）
  PlaceName 顯示
  遊戲規則顯示
  加入 / 離開 按鈕
  Map 縮圖（顯示 Room 的模糊位置）

訂閱：
  roomUpdated Subscription → 即時更新座位狀態
  有人加入時的動畫（SeatCard 的 flip 動畫）
```

**RoomFullPage**：

```
觸發時機：roomUpdated 收到 ROOM_FULL event

Layout：
  慶祝動畫（confetti 或彩帶）
  「4 人到齊！」大標題
  PlaceName 文字
  地圖（此時顯示精確座標）
  「導航前往」按鈕（開啟 Apple Maps / Google Maps）
  成員列表（4 個頭像）
```

**CreateRoomPage**：

```
Layout：
  Room 名稱輸入
  場地名稱輸入（PlaceName）
  地圖 pin 選點（預設當前位置，可拖動）
  遊戲規則選擇（3 個選項）
  公開 / 好友限定 toggle
  建立按鈕

驗證：
  名稱必填（< 30 字）
  場地名稱必填（< 50 字）
  位置必須已選擇
```

---

### 8.4 Design System 規格

---

**Nina**：

```
顏色系統（app_colors.dart）：
  Primary：#E85C26（麻將牌的紅色，亮眼）
  Secondary：#2B5EAB（藍色，沉穩）
  Background：#F5F5F0（米白，類似麻將牌顏色）
  Surface：#FFFFFF
  Error：#D32F2F
  Success：#388E3C
  FriendAccent：#FF6B35（好友 Marker 的橙色）
  StrangerAccent：#78909C（陌生人 Marker 的灰藍色）

字型：
  Display：24px bold（RoomFull 標題）
  Headline：20px bold（頁面標題）
  Body：16px regular（內文）
  Caption：12px regular（最後更新時間等次要資訊）

間距：
  xs：4px，sm：8px，md：16px，lg：24px，xl：32px

圓角：
  small：4px，medium：8px，large：16px，pill：999px

Marker 尺寸：
  FriendMarker：60×80px
  StrangerMarker：40×40px
  RoomMarker：自定義 Widget（約 80×60px）
  MyLocationMarker：20×20px（圓點）+ 廣播圈
```

---

## 9. 效能設計

### 9.1 地圖 Marker 更新效能

---

**Amy**：最容易出效能問題的場景是：

```
場景 1：500ms batch 到期，一次更新 20 個陌生人 Marker
  問題：全部 rebuild FlutterMap → 可能掉幀
  解法：
    - 用 Marker key 做 diffing（只 rebuild 變動的 Marker）
    - 好友 Marker 和陌生人 Marker 分成不同的 MarkerLayer（減少 rebuild 範圍）
    - Marker Widget 用 const constructor（讓 Flutter diff 更快）

場景 2：快速滑動地圖時，大量 Tile 載入
  解法：flutter_map_cache 本地快取，已載入的 Tile 不重複下載

場景 3：ClusterLayer 在 zoom 變化時重新計算 cluster
  解法：debounce zoom change（zoom 停止變化 200ms 後才重新計算）
```

---

### 9.2 Widget 效能原則

---

**Chen**：給 Nina 的 Widget 開發指引：

```
必須遵守：
  1. const constructor：只要 Widget 沒有運算，加 const
     → const FriendMarkerWidget(...)

  2. 不在 build() 裡做計算
     → 排序、過濾放到 Provider（State Layer）
     → build() 只做 UI 渲染

  3. RepaintBoundary：把地圖和其他 UI 元素隔離
     → FlutterMap 更新不影響 BottomNavigationBar 重繪

  4. Selector 精確訂閱：只 watch 需要的欄位
     → ref.watch(nearbyPlayersMapProvider.select((p) => p.friends))
     → 只有好友列表變動才 rebuild，陌生人更新不觸發 rebuild

  5. ListView.builder 代替 Column
     → 好友列表用 ListView.builder（only build visible items）
```

---

## 10. 測試策略

### 10.1 測試分層

---

**David**：

```
Layer 1：Unit Test（最多）
  測試對象：Provider、Notifier、Repository（mock API）
  工具：flutter_test + mocktail
  不需要：真實 GraphQL server

  重點測試：
    BroadcastNotifier：startBroadcast 後 state 從 null 變成 Broadcast
    RoomNotifier：joinRoom 後 seats 更新
    Error Handling：ROOM_FULL error 正確轉換成 AppException

Layer 2：Widget Test
  測試對象：關鍵 Widget 的 UI 正確性
  工具：flutter_test + alchemist（Golden test）
  重點測試：
    FriendMarkerWidget：有頭像 + 名字 + 距離
    SeatCard：空位 vs 有人的樣式
    RoomFullPage：正確顯示所有成員和地點

Layer 3：Integration Test
  測試對象：關鍵 User Journey（自動化）
  工具：flutter_integration_test
  重點測試：
    登入流程
    開始廣播 → 停止廣播
    建立 Room → 加入 Room
```

---

### 10.2 Mock 策略

---

**David**：

```
Ferry 的 Mock：
  ferry 有 MockClient，可以模擬 GraphQL response 和 Subscription stream
  不需要連接真實 server 就能測試 UI

Provider 的 Mock：
  Riverpod 的 ProviderScope 可以 override Provider
  測試時注入 mock repository，不需要真實 API

範例：
  // 覆蓋 broadcastRepository 為 mock 版本
  ProviderScope(
    overrides: [
      broadcastRepositoryProvider.overrideWith((ref) => MockBroadcastRepository()),
    ],
    child: MyApp(),
  )
```

---

## 11. MVP Roadmap 與任務分配

### 11.1 Phase 0：環境建置（Week 1，與後端同步）

**目標**：Flutter 專案跑起來，基礎設施就緒

| 任務 | 負責人 | 說明 |
|------|--------|------|
| Flutter 專案初始化 | Chen | 建立目錄結構、設定 `pubspec.yaml` |
| Ferry + gqlgen 設定 | David | `build.yaml`、`.graphql` 操作文件框架 |
| Riverpod 基礎 Provider 設定 | David | Infrastructure Providers |
| GoRouter 設定 | Nina | 所有路由定義、Guard |
| Design System 基礎建立 | Nina | 顏色、字型、間距常數 |
| FlutterMap 基礎顯示 | Amy | 地圖顯示、當前位置 pin |
| OAuth 整合（Apple + Google）| Chen | 取得 access token，送給後端換 JWT |
| flutter_secure_storage JWT 存取 | David | Login / Logout / Auto-login |
| Hive 初始化 | David | Box 設定 |
| Sentry + Firebase Analytics 初始化 | Nina | |

**完成標準**：

```
Flutter App 可以跑在 iOS 模擬器 + Android 模擬器
Apple/Google 登入可以完成，JWT 存入 Keychain
地圖可以顯示，可以取得當前位置
所有路由可以跳轉（即使頁面是空的）
```

---

### 11.2 Phase 1a：Auth + 地圖基礎（Week 2，配合後端 Phase 1a）

**目標**：登入流程完整，地圖可以顯示廣播

| 任務 | 負責人 | 說明 |
|------|--------|------|
| LoginPage UI 完成 | Nina | Apple/Google 按鈕樣式 |
| Auth flow（Ferry mutation + token 存取）| David | refreshToken 機制 |
| 從後端拿 nearbyBroadcasts（Query）| Amy | 地圖上顯示廣播 Marker |
| BroadcastFAB（開始/停止廣播）| Nina | 確認 Dialog + loading state |
| BroadcastNotifier | David | startBroadcast / stopBroadcast mutation |
| 廣播中的圈圈動畫 | Nina | MyLocationLayer 的廣播範圍視覺化 |
| Heartbeat（每 5 分鐘）| David | 背景 Timer，呼叫 heartbeat mutation |
| Onboarding 3 頁 | Nina | 首次啟動才顯示，SharedPreferences 記錄 |
| EmptyStateOverlay | Nina | 附近沒人時的 CTA |

---

### 11.3 Phase 1b：Subscription 即時推送（Week 4，配合後端 Phase 1b）

**目標**：地圖即時更新，A 廣播 B 立刻看到

| 任務 | 負責人 | 說明 |
|------|--------|------|
| WebSocket Link 設定（graphql-ws）| David | connection_init JWT 注入 |
| nearbyPlayerUpdates Subscription | David | StreamProvider 接 ferry stream |
| 連線狀態管理（ConnectionStateProvider）| David | connected/reconnecting/offline |
| Reconnect + Snapshot refetch | David | 斷線重連後補齊資料 |
| 連線狀態 UI Banner | Nina | 頂部 banner 動畫 |
| Marker 動畫（好友上線/下線）| Nina | flutter_animate scale + fade |
| 陌生人 Marker Clustering | Amy | MarkerClusterLayer 設定 |
| Marker Tap → PlayerInfoSheet | Amy | 底部 Sheet 顯示玩家資訊 |

---

### 11.4 Phase 1c：好友系統（Week 5，配合後端 Phase 1c）

**目標**：好友列表完整，好友 Marker 優先顯示

| 任務 | 負責人 | 說明 |
|------|--------|------|
| FriendsPage（好友列表）| Nina | 搜尋用戶、發送/接受好友請求 |
| 好友請求 Badge（BottomNavBar）| Nina | 未讀請求數顯示 |
| friendBroadcastEvents Subscription | David | 好友廣播即時通知 |
| 好友 Marker 優先顯示（頂層）| Amy | Layer 4 永遠在陌生人 Layer 上 |
| activeFriendBroadcastsProvider | David | 正在廣播的好友列表 |
| 好友動態列表（FriendsPage Tab）| Nina | 哪些好友現在在廣播 |
| blockUser + 雙向不可見 UI | Nina | Profile 頁的封鎖按鈕 |
| Hive 快取好友列表 | David | 離線可見好友列表 |

---

### 11.5 Phase 1d：Room 系統（Week 6-7，配合後端 Phase 1d）

**目標**：完整組局流程，4 人到齊有 FCM 通知

| 任務 | 負責人 | 說明 |
|------|--------|------|
| CreateRoomPage | Nina | 地點選擇、規則選擇、公開設定 |
| 地圖 Pin 選點 UI（CreateRoom 用）| Amy | 可拖動的 MapPicker Widget |
| RoomDetailPage + SeatCards | Nina | 4 個座位的即時顯示 |
| roomUpdated Subscription | David | 即時更新座位 |
| 加入座位動畫（SeatCard flip）| Nina | flutter_animate |
| RoomFullPage | Nina | 慶祝動畫 + 精確位置 + 導航按鈕 |
| FCM 接收（Room 通知）| David | 點擊通知 → 跳轉 RoomDetailPage |
| NearbyRooms 列表 | Amy | 地圖上的 Room Marker |
| RoomInfoSheet（點擊 Room Marker）| Nina | 顯示 Room 資訊、加入按鈕 |
| 導航按鈕（Apple Maps / Google Maps）| Amy | `url_launcher` 開啟導航 App |

---

### 11.6 Phase 2：Production Hardening（Week 8-9）

| 任務 | 負責人 | 說明 |
|------|--------|------|
| 完整 Error Handling UI | Nina | 所有 error code 的 UI 反饋 |
| 帳號年齡限制 UI | Nina | 倒計時顯示 |
| App Icon + Splash Screen | Nina | 正式圖示和啟動畫面 |
| 各頁面 Loading Skeleton | Nina | 避免 flash of empty content |
| 所有 Widget Test（Golden）| David + Nina | 關鍵頁面的 Golden test |
| Integration Test（User Journey）| David + Amy | 自動化 E2E 流程 |
| iOS Background Location 設定 | Amy | Info.plist + App Store 說明文件 |
| Android Background Location 設定 | Amy | Manifest + 權限說明 |
| 效能測試（Profile mode）| Amy | 500 Marker 不掉幀驗證 |
| Accessibility 基礎（a11y）| Nina | 按鈕有 semanticsLabel |

---

### 11.7 Phase 3：Beta 準備（Week 10-13）

| 任務 | 負責人 | 說明 |
|------|--------|------|
| Feature Freeze（Week 10）| All | 不接受新功能 |
| App Store Privacy 說明文件 | Amy + Sarah(PM) | 定位資料說明 |
| TestFlight Beta 送審 | Chen | 需 2-3 天審查時間 |
| Firebase App Distribution（Android）| Chen | |
| Beta 用戶反饋收集機制 | Nina | App 內的 Feedback 按鈕 |
| Bug fix（Beta 回饋）| All | Critical bug 立即修 |

---

### 11.8 正式上線（Week 14）

| 任務 | 負責人 |
|------|--------|
| App Store 正式送審（提前 7 天）| Chen |
| Play Store 正式發布 | Chen |
| App Store Connect + Play Console 設定 | Chen |
| Release Notes 撰寫 | Nina + PM |

---

### 11.9 Post-MVP Flutter Roadmap

| 功能 | 月份 | 說明 |
|------|------|------|
| FCM 好友廣播通知 UI | M2 | 點擊通知 → 地圖 highlight 好友 |
| 好友限定廣播 UI | M2 | CreateRoom/Broadcast 的可見性選擇 |
| Room 規則篩選 UI | M2 | NearbyRooms 的 filter bar |
| 聊天 UI（Room 內）| M3 | NATS Streams 後端就緒後 |
| 廣播歷史 UI | M3 | 我的廣播紀錄頁面 |
| 廣播半徑滑桿 | M3 | 0.5~50km 選擇 |
| 評價系統 UI | M4 | 打完麻將後互評 |
| Widget（iOS/Android）| M3 | 好友廣播狀態 Home Screen Widget |

---

## 12. React 19 網頁端評估

### 12.1 評估討論

---

**Chen**：PM 那邊問過我們是否要做網頁版。在 Flutter MVP 穩定前，我不建議分散資源。但我們要想清楚未來的選擇，以免現在的架構決定造成以後的困難。

**David**：從技術層面，React 19 做網頁版的優勢是什麼？

**Chen**：主要的使用場景是「電腦端管理」——用戶在電腦上看自己的廣播歷史、管理好友、查看 Room 記錄，不需要即時定位。這些功能不需要原生 App 能力，做成網頁更方便。

**Alex（後端）**：後端的 GraphQL API 是跨平台的，Flutter 和 React 都可以用同一套 API，不需要為網頁版另外開 API。

---

### 12.2 React 19 評估

---

**David**：

```
React 19 的新特性對我們有用的：

  1. Server Components（RSC）
     → 可以在 server 端執行 GraphQL Query，減少 client 的請求
     → 適合：廣播歷史、用戶資料等不需要即時更新的頁面
     → 不適合：即時地圖（需要 client-side WebSocket）

  2. Actions
     → 表單提交和 mutation 的簡化 API
     → createRoom、updateProfile 等 mutation 可以用 Action

  3. use() hook
     → 在 render 中直接 await Promise
     → 和 Apollo / urql 整合會更乾淨

GraphQL Client 選擇：
  Apollo Client 3.x → 穩定，React Query 整合好
  urql → 更輕量，更好的 Server Components 支援
  Relay → Facebook 自家，但學習成本高

地圖選擇（Web 版）：
  Leaflet.js（和 flutter_map 底層 OSM 一致，視覺上統一）
  Mapbox GL（更漂亮，有付費方案）
```

---

### 12.3 是否做 React 19 的建議

---

**Chen**：我的結論是：

```
現在（MVP 階段）：不做
  理由：
    1. 資源有限（Flutter team 4 人，MVP 就已經很滿）
    2. 網頁端的即時定位體驗遠不如原生 App（Web Geolocation API 限制多）
    3. 核心使用場景（找人打麻將）是即時的、移動的，需要原生 App 體驗

考慮做的時機（Post-MVP M3 之後）：
  條件 1：Flutter App DAU 穩定 > 3,000
  條件 2：有以下明確需求之一：
    - 電腦端管理後台（管理廣播歷史、好友、Room 記錄）
    - 比賽/活動主辦方需要電腦端操作
    - SEO 需求（讓 Google 索引到「台北找麻將」相關內容）

如果決定做，架構選擇：
  Next.js 15（App Router）+ React 19
  GraphQL Client：urql（Server Components 支援更好）
  地圖：Leaflet.js + OpenStreetMap（和 Flutter 端一致）
  不重做即時地圖功能，Web 版定位是「管理後台」，不是「即時找人」
```

**Amy**：如果未來做 React，我們現在要做什麼準備？

**Chen**：

```
現在就要做的準備（成本很低）：

  1. GraphQL .graphql 操作文件整理好
     → Flutter 用 ferry generator
     → React 未來用 graphql-code-generator，可以共用同一份 .graphql 文件

  2. 確保後端 API 沒有平台特定的設計
     → Alex 已確認 API 設計是平台中立的，沒問題

  3. 設計資產（顏色、字型）用設計 token 管理
     → Nina 的 Design System 如果用 Style Dictionary，未來可以匯出 CSS 變數給 React 用

不需要現在做的：
  不需要建 React 專案
  不需要建 monorepo 同時管 Flutter 和 React
```

---

### 12.4 React 19 評估結論

| 評估項目 | 結論 |
|----------|------|
| 是否在 MVP 做 | ❌ 不做 |
| 做的時機 | Post-MVP M3+，DAU > 3,000 後評估 |
| 主要使用場景 | 管理後台，非即時找人 |
| 技術選擇（若做）| Next.js 15 + urql + Leaflet.js |
| 現在需要準備 | 整理好 .graphql 操作文件，其他不需要 |
| 資源需求（若做）| 需要 1-2 位 React 工程師，或 Flutter 工程師轉型 |

---

## 13. 開放問題清單

| ID | 問題 | 影響 | 負責人 | 截止 |
|----|------|------|--------|------|
| F01 | iOS Background Location 的 App Store 說明文字確認？ | Week 8 準備 | Amy + Sarah | Week 7 |
| F02 | 地圖 Tile provider：OSM 免費版或付費 Maptiler？（高流量時 OSM 可能限流）| 上線後 | Chen | Week 10 |
| F03 | Marker 點擊 Sheet 高度：half-screen 或 full-screen？ | UX 設計 | Nina + Kevin(PM) | Week 3 |
| F04 | RoomFullPage 的慶祝動畫：confetti 或其他？需要 PM 確認風格 | UX 設計 | Nina + Sarah | Week 6 |
| F05 | 用戶頭像上傳：直接用 GraphQL mutation 還是 S3 presigned URL？ | API 設計 | David + Alex | Week 2 |
| F06 | Android 最低支援版本（API level）？影響 WorkManager 使用 | 開發範圍 | Amy | Week 1 |
| F07 | iOS 最低支援版本？影響 SwiftUI 相關功能 | 開發範圍 | Amy | Week 1 |
| F08 | 好友動態列表是否需要單獨的 Subscription，還是共用 nearbyPlayerUpdates？ | API 設計 | David + Alex | Week 5 |
| F09 | Deep link 格式：custom scheme 或 universal link？ | SEO + UX | Chen + Alex | Week 3 |
| F10 | 離線時地圖顯示最後已知的廣播 Marker，是否會造成用戶誤解？ | UX | Nina + Kevin | Week 4 |

---

*文件版本：v1.0*
*Flutter 團隊確認：Chen ✅ Amy ✅ David ✅ Nina ✅*
*後端確認：Alex ✅*
*PM 確認：Sarah ✅ Kevin ✅（React 19 評估結論）*
*下次回顧：Week 4（Phase 1b 完成後）*
