# 麻將找人定位系統 — 規格書 v2.0

> **文件性質**：Production Architecture & Design Specification（修訂版）
> **版本**：v2.0 — 整合 PM Review 後的正式版本
> **日期**：2026-03-28
> **參與者**：Alex（Senior Go Backend）、Ben（Senior Go Infra）、Chen（Senior Flutter）、Sarah（PM Strategy）、Kevin（PM Growth）

---

## 目錄

1. [修訂說明與討論記錄](#1-修訂說明與討論記錄)
2. [產品定位與核心假設](#2-產品定位與核心假設)
3. [領域模型（DDD）](#3-領域模型ddd)
4. [系統架構](#4-系統架構)
5. [GraphQL API 設計](#5-graphql-api-設計)
6. [後端服務架構](#6-後端服務架構)
7. [Flutter 客戶端架構](#7-flutter-客戶端架構)
8. [資料層設計](#8-資料層設計)
9. [基礎設施](#9-基礎設施)
10. [可觀測性](#10-可觀測性)
11. [安全與濫用防護](#11-安全與濫用防護)
12. [MVP 範圍定義](#12-mvp-範圍定義)
13. [開發里程碑](#13-開發里程碑)
14. [風險登記冊](#14-風險登記冊)
15. [ADR 架構決策記錄](#15-adr-架構決策記錄)
16. [開放問題清單](#16-開放問題清單)

---

## 1. 修訂說明與討論記錄

### 1.1 本次修訂的工程 × PM 對焦討論

---

**Alex**：我把 PM Review 仔細看完了。Sarah 和 Kevin 找到的問題不是挑剔，是真的有幾個地方我們工程師視角盲掉了。最嚴重的是 Room 地點的問題——我們設計了 `location: GeoPoint`，但完全沒想到「4 人到齊後要去哪裡打」這個流程。地圖座標對用戶來說毫無意義，他需要的是地址。

**Ben**：另一個讓我反思的是 NATS 的決定。我們 v1.0 從一開始就選 NATS JetStream，理由是 50K DAU 的 fan-out 量。但 Kevin 和 Sarah 把 MVP DAU 目標修正為 1,000，這個量用 Redis Pub/Sub 完全沒問題。我們過度設計了。抽象 Publisher Interface 是正確的，但基礎設施不應該從 Day 1 就這麼重。

**Chen**：從 Flutter 端，我最大的收穫是 FCM 通知的問題。Kevin 說「沒有通知 Host 就不知道有人加入 Room」，這個我當時沒想到，因為我習慣性地假設 Host 會一直開著 App。現實是用戶建完 Room 就去做別的事了。這讓 FCM 至少在 Room 場景必須是 P1。

**Sarah**：我也想說工程那邊做得好的地方。Risk Register 和 ADR 這兩個東西很多 PM 都沒見過，它們讓我們討論有了具體的錨點。Kevin 說「10 週時程過於樂觀」，這個判斷其實就是從 Risk R09（App Store 審查風險）出發的。

**Kevin**：這次修訂我有兩個核心要求。第一，規格書要回答「為什麼用戶選擇這個 App」，這是業務方向，決定了後面所有設計取捨。第二，Room 的完整 lifecycle 要定義清楚，包括地點顯示、滿員後的導引流程、規則選擇，這些直接影響 GraphQL Schema。

**Alex**：在開始修訂前，我需要和兩位 PM 確認三件事。

---

### 1.2 工程向 PM 的需求確認（修訂前對焦）

---

**Alex**：第一件事：Room 的地點資料。我需要知道地點是「地圖座標 + 用戶填的名稱」就夠了，還是需要整合 Geocoding API 把座標轉成地址？兩者的工程成本差很多。

**Kevin**：產品期望是：Host 可以在地圖上拖動 pin 選地點，同時可以輸入一個「場地名稱」（例如「我家」、「XX 棋牌室」）。不需要自動 Geocoding，讓用戶自己填名稱就好。座標用來做地圖顯示和距離計算。

**Alex**：好，這樣我不需要引入第三方 Geocoding API，Room entity 加 `placeName: String` 就夠了。成本大幅降低。

**Ben**：第二件事：FCM。PM 說 Room 通知升 P1，我想確認具體要送哪些通知，因為 FCM 整合有固定的工程成本，我要把它放進正確的 Phase。

**Sarah**：P1 通知清單（MVP 必做）：
- 「有人加入你的 Room」（送給 Host）
- 「Room 已滿，可以開打了！」（送給所有成員）

P2 通知清單（v1.1）：
- 「好友開始廣播了，附近有人找麻將」
- 「你收到好友邀請」

**Ben**：清楚。P1 是 2 個通知類型，這個量我可以在 Phase 1d（Room phase）一起做，不需要獨立 Phase。

**Chen**：第三件事，也是我最需要確認的：Onboarding 和空狀態。規格書 v1.0 沒有這個，但它影響我的 Flutter navigation 架構。空狀態是一個獨立頁面，還是在主地圖頁面上 overlay？

**Kevin**：空狀態是主地圖頁面的 overlay，不是獨立路由。用戶看到空地圖 + 一個浮動的 CTA 按鈕「開始廣播找人」。Onboarding 是 App 第一次啟動時的 3 頁滑動教學，之後進入主地圖。Week 3 我會交 wireframe，你先把 navigation 架構的 slot 預留好。

**Chen**：好，我先把 `OnboardingFlow` 和 `EmptyStateOverlay` 作為 widget 預留位置，wireframe 來了再填實作。

---

### 1.3 本次修訂的核心變更摘要

| 變更類別 | v1.0 | v2.0 |
|----------|-------|-------|
| **文件風格** | 大量程式碼為主 | 架構設計為主，程式碼只做概念說明 |
| **Pub/Sub** | NATS JetStream（Day 1）| Redis Pub/Sub（MVP）+ Publisher Interface（預留替換路徑）|
| **DB 架構** | Primary + 2 Read Replica | 單一 PostgreSQL（MVP），Read Replica 標注為 v1.1 |
| **BroadcastStatus** | ACTIVE / PAUSED / STOPPED | ACTIVE / STOPPED（移除 PAUSED）|
| **Room 地點** | 僅 GeoPoint | GeoPoint + placeName（用戶填寫）|
| **Room 屬性** | 基本 4 欄位 | 新增 gameRule、isPublic、placeName |
| **Room 地點可見性** | 全程精確 | WAITING=模糊，FULL 後=精確 |
| **FCM 通知** | P2（好友廣播）| Room 通知升 P1，好友廣播維持 P2 |
| **時程** | 10 週上線 | 14 週（Week 10 Feature Freeze，Week 14 正式上線）|
| **MVP DAU 目標** | 5,000 | 1,000（Beta 城市集中策略）|
| **好友上限** | 500 | 200（MVP）|
| **安全** | 技術安全為主 | 新增帳號年齡限制、封鎖行為規格、濫用防護 |
| **成功指標** | 無 | 新增北極星指標與 KPI 門檻 |
| **用戶旅程** | 無 | 新增完整 User Journey（場景 A/B）|

---

## 2. 產品定位與核心假設

### 2.1 產品定位

**一句話定義**：讓想打麻將的人，在地圖上即時找到附近的搭子，5 分鐘內組成一局。

**我們替代的是什麼**：LINE 群廣播「有沒有人打麻將」、Facebook 社團發文找人。這些方式的問題是：非即時、受眾不精準、沒有地點資訊。

**核心差異化**：
- 即時位置廣播（不是發文等人回覆）
- 好友優先推送（先問認識的人）
- Room 系統（從「找人」到「組局」一條龍）

**冷啟動策略**：MVP 只在台北市推廣（Beta 300-500 人），確保地圖有足夠密度。空狀態引導用戶成為第一個廣播者。

### 2.2 業務假設（v2.0 已確認版）

| 假設項目 | 值 | 狀態 | 確認來源 |
|----------|-----|------|----------|
| MVP DAU 目標 | 1,000 | ✅ | PM 2026-03-28 |
| 6 個月 DAU 目標 | 10,000 | ✅ | PM |
| Beta 地區 | 台北市 | ✅ | PM |
| 好友上限（MVP）| 200 人 | ✅ | PM |
| 廣播可見範圍 | 固定 5km（MVP）| ✅ | PM |
| 廣播最長時間 | 4 小時 | ✅ | PM |
| Room 人數 | 固定 4 人 | ✅ | 業務規則 |
| 更新頻率（Foreground）| 每 5 秒 | ✅ | 工程建議 |
| 更新頻率（Background）| 每 60 秒 | ✅ | 工程建議 |
| Pub/Sub 方案（MVP）| Redis Pub/Sub | ✅ | 工程決議 |
| App 年齡限制 | 17+（App Store）| ✅ | PM + 法規考量 |
| SLA | 99.9% | `[?]` | 待 CEO 確認 |
| 資料保留期 | 30 天 | `[?]` | 待法律確認 |
| 付費模型時間點 | 未定 | `[?]` | 待業務確認 |

### 2.3 關鍵數字估算（基於修訂假設）

```
=== MVP（1,000 DAU）===
Active broadcasters（20%）：200 人
Fan-out peak：200 × 12 updates/min × 200 friends = 480,000 events/min = 8,000 pub/s
WebSocket concurrent：~300 連線
→ Redis Pub/Sub 可以處理，NATS 非必要

=== 6 個月成長（10,000 DAU）===
Fan-out peak：2,000 × 12 × 200 = 4,800,000 events/min = 80,000 pub/s
→ 接近 Redis Pub/Sub 上限，此時觸發 NATS 替換
→ Publisher Interface 設計保證替換時 application code 不需改動

=== 資料寫入量（10,000 DAU）===
位置更新（Foreground 30%）：3,000 users × 12/min = 36,000 writes/min = 600 writes/s
位置更新（Background 70%）：7,000 users × 1/min = 7,000 writes/min ≈ 117 writes/s
Peak（3× 平均）：~2,100 writes/s
→ 批次寫入設計可輕鬆處理
```

### 2.4 成功指標（北極星與 KPI）

**北極星指標**：每週 `RoomFull` 的不重複 Room 數（代表成功配對次數）

**Beta 結束門檻（Week 13）**：

| 指標 | 目標 | 說明 |
|------|------|------|
| D1 Retention | ≥ 30% | 次日留存 |
| D7 Retention | ≥ 12% | 7 日留存 |
| 首次配對成功率 | ≥ 40% | Beta 用戶完成至少一次 RoomFull 的比例 |
| 首次配對等待時間（中位數）| ≤ 20 分鐘 | startBroadcast 到加入滿員 Room |
| App Crash Rate | ≤ 1% | Sentry crash-free sessions |
| p99 latency | ≤ 500ms | GraphQL query/mutation |

---

## 3. 領域模型（DDD）

### 3.1 Bounded Context 劃分

```
┌─────────────────────────────────────────────────────────┐
│                     Context Map                          │
│                                                          │
│  ┌─────────────┐    ┌─────────────────┐                 │
│  │ Identity BC │───▶│  Discovery BC   │                 │
│  │             │    │                 │                 │
│  │ User        │    │ Broadcast       │                 │
│  │ Auth        │    │ NearbySearch    │                 │
│  │ Profile     │    │ GeoIndex        │                 │
│  └─────────────┘    └────────┬────────┘                 │
│                              │                           │
│  ┌─────────────┐    ┌────────▼────────┐                 │
│  │  Social BC  │◀──▶│    Room BC      │                 │
│  │             │    │                 │                 │
│  │ Friendship  │    │ Room / Seat     │                 │
│  │ FriendPush  │    │ RoomLifecycle   │                 │
│  │ Block       │    │ GameRule        │                 │
│  └─────────────┘    └────────┬────────┘                 │
│                              │                           │
│              ┌───────────────▼───────────┐              │
│              │     Notification BC        │              │
│              │  FCM / In-App / WebSocket  │              │
│              └───────────────────────────┘              │
└─────────────────────────────────────────────────────────┘
```

**各 BC 職責與邊界**：

| BC | 核心職責 | 對外依賴 |
|----|----------|----------|
| Identity | 用戶身份、OAuth、JWT 生命週期 | 無（Upstream）|
| Discovery | 位置廣播、GeoIndex、附近搜尋 | Identity |
| Social | 好友關係、封鎖、Friend Priority | Identity |
| Room | 麻將組局全生命週期 | Identity、Discovery、Social |
| Notification | FCM push、WebSocket 事件路由 | 所有 BC（事件消費者）|

### 3.2 核心 Domain Events

**Discovery BC**

| Event | 觸發時機 | 關鍵資料 |
|-------|----------|----------|
| `BroadcastStarted` | 用戶開始廣播 | playerID, location, radius |
| `BroadcastStopped` | 手動停止 / TTL 到期 / 進 Room | playerID, stopReason |
| `LocationUpdated` | 位置移動超過 50m | playerID, oldLoc, newLoc, delta |

**Room BC**

| Event | 觸發時機 | 關鍵資料 |
|-------|----------|----------|
| `RoomCreated` | createRoom Mutation | roomID, hostID, location, placeName, gameRule |
| `PlayerJoinedRoom` | joinRoom Mutation | roomID, playerID, seatPosition |
| `PlayerLeftRoom` | leaveRoom / kickPlayer | roomID, playerID, leaveReason |
| `RoomFull` | 第 4 位玩家加入 | roomID, [4]playerID → 觸發：BroadcastStopped × 4 |
| `RoomDissolved` | dissolveRoom / Host 離開 | roomID, dissolveReason |
| `HostTransferred` | transferHost | roomID, oldHostID, newHostID |

**Social BC**

| Event | 觸發時機 |
|-------|----------|
| `FriendRequestSent` | sendFriendRequest |
| `FriendshipEstablished` | acceptFriendRequest → 觸發：好友 cache invalidation |
| `UserBlocked` | blockUser → 觸發：雙向 fan-out 過濾更新 |

### 3.3 聚合根設計原則

**Broadcast Aggregate**

- **不變量**：同一 Player 同時只能有一個 ACTIVE 廣播
- **生命週期**：ACTIVE → STOPPED（單向，無 PAUSED）
- **過期機制**：Redis TTL 心跳（10 分鐘），Client 每 5 分鐘 heartbeat
- **Significant Change Filter**：位置變動 < 50m 時不觸發 LocationUpdated，減少不必要的 publish

**Room Aggregate**

- **不變量**：
  - 最多 4 個 Seat
  - FULL / CLOSED 狀態不允許新玩家加入
  - 同一 Player 不能同時在兩個 Room
  - Host 是唯一可以 dissolve / kick 的人
- **狀態機**：

```
WAITING ──(第4人加入)──▶ FULL ──(未來：確認到場)──▶ PLAYING
   │                       │
   │(Host 離開 / 超時)      │(任意玩家離開)
   ▼                       ▼
CLOSED ◀──────────────────┘
```

- **Room 地點可見性規則**：
  - WAITING：回傳模糊座標（±150m 隨機偏移）+ placeName
  - FULL 後：回傳精確座標 + placeName（Resolver 層依 status 決定）

### 3.4 Repository Interfaces（Domain 層定義）

> 設計原則：Domain 層只定義 interface，不依賴任何基礎設施實作。測試時可以 mock，基礎設施替換時 Domain 不需改動。

**五個核心 Repository Interface**：

- `BroadcastRepository`：Save / FindByPlayerID / FindNearby / Delete
- `RoomRepository`：Save / FindByID / FindByPlayerID / FindWaitingNearby / Delete
- `FriendshipRepository`：Save / FindFriends / IsFriend / Delete
- `LocationHistoryRepository`：BatchAppend（批次寫入，不支援單筆）
- `UserRepository`：Save / FindByID / FindByOAuth / SoftDelete

**Publisher Interface（關鍵抽象）**：

```
Publisher Interface：
  Publish(ctx, subject string, payload []byte) error

MVP 實作：RedisPublisher（Redis Pub/Sub）
未來實作：NATSPublisher（NATS JetStream）
替換條件：DAU 超過 5,000，fan-out 接近 Redis Pub/Sub 上限時
```

---

## 4. 系統架構

### 4.1 整體架構圖

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client Layer                              │
│              Flutter App（iOS / Android）                        │
│   ┌──────────────┬────────────────┬───────────────────────┐    │
│   │ GraphQL/ferry│ Google Maps /  │  Local Cache（Hive）  │    │
│   │ WebSocket    │ flutter_map    │  FCM Token 管理        │    │
│   └──────┬───────┴────────────────┴───────────────────────┘    │
└──────────┼──────────────────────────────────────────────────────┘
           │ HTTPS + WSS
┌──────────▼──────────────────────────────────────────────────────┐
│              Edge：Cloudflare（DDoS + WAF + CDN）                │
└──────────┬──────────────────────────────────────────────────────┘
           │
┌──────────▼──────────────────────────────────────────────────────┐
│        API Gateway：nginx（SSL Termination + Rate Limit）        │
└──────┬───────────────────────────────────────────────────────────┘
       │
┌──────▼───────────────────────────────────────────────────────┐
│               GraphQL Gateway（Go / gqlgen）                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Query Resolver │ Mutation Resolver │ Subscription Hub  │ │
│  │  Auth Middleware (JWT)  │  Rate Limit Middleware         │ │
│  └────────────────────────────────────────────────────────-┘ │
└──────┬───────────────────┬────────────────────────────────────┘
       │ gRPC              │ gRPC
┌──────▼──────┐    ┌───────▼──────┐    ┌───────────────┐
│  Discovery  │    │    Room      │    │    Social     │
│  Service    │    │  Service     │    │   Service     │
│   (Go)      │    │    (Go)      │    │    (Go)       │
└──────┬──────┘    └───────┬──────┘    └───────┬───────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │  Pub/Sub（Redis MVP / NATS Scale）
┌──────────────────────────▼──────────────────────────────────┐
│                      Redis Cluster                           │
│   GeoSet（活躍廣播）│ Pub/Sub │ Cache │ Session │ TTL Keys  │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                     PostgreSQL                               │
│    Primary（寫）  │  TimescaleDB Extension（位置歷史）       │
│                   │  Read Replica × 2（v1.1 加入）           │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 服務間通訊策略

| 通訊路徑 | 協議 | 理由 |
|----------|------|------|
| Client ↔ Gateway | GraphQL over HTTPS/WSS | 統一入口，客戶端不知道後端有幾個服務 |
| Gateway ↔ Services | gRPC（internal）| 強型別，低延遲，支援 streaming |
| Services → Pub/Sub | Redis Pub/Sub Client | 非同步 fan-out |
| Pub/Sub → Gateway | Redis Subscribe | Subscription push |
| Notification BC | FCM HTTP v1 API | Push notification |

### 4.3 Pub/Sub Channel 設計

```
MVP（Redis Pub/Sub）：

  broadcast:geo:{geohash5}        → 陌生人廣播（按地理分散）
  broadcast:geo:{geohash5}:adj    → 邊界相鄰格子（防止漏掉邊界玩家）
  broadcast:friend:{userID}       → 好友專屬高優先 channel
  room:update:{roomID}            → Room 狀態變更
  notification:push:{userID}      → FCM 觸發信號

未來（NATS JetStream Subject 設計相同，只換底層實作）：
  上述 subject 命名不變，Publisher Interface 替換即可
```

### 4.4 好友優先推送機制

這是系統設計的核心差異點，需要細說：

```
廣播發生時的 fan-out 流程：

1. Player A startBroadcast
        │
        ├─→ GeoIndex.Add（Redis GeoSet）
        │
        ├─→ Publisher.Publish("broadcast:geo:{hash}", event)  [陌生人]
        │
        └─→ for each friend in A.Friends:
                Publisher.Publish("broadcast:friend:{friendID}", event)  [好友]

Subscription Resolver 的雙 channel 設計：

  訂閱者（B）同時訂閱：
    - "broadcast:friend:{B.userID}"   → 好友事件，立即 push
    - "broadcast:geo:{B.geohash}"     → 陌生人事件，500ms batch

  去重機制：
    - 維護 in-memory friendSet
    - 陌生人 channel 收到事件時，若發送者在 friendSet 中，丟棄（已從 friend channel 處理）

  Back-pressure 策略：
    - 好友事件：阻塞等待（最多 5s），不可 drop
    - 陌生人事件：buffer 滿時 drop，記錄 metric
```

---

## 5. GraphQL API 設計

### 5.1 Schema 設計原則

- **單一入口**：所有 client 操作只透過 GraphQL Gateway，不直接呼叫內部 service
- **版本策略**：不做版本號，用 deprecated 標注廢棄欄位，Schema evolution 而非 breaking change
- **錯誤規格**：業務錯誤透過 `extensions.code` 標準化，不用 HTTP status code
- **分頁**：列表型資料統一用 Relay Cursor Connection（`first` + `after`）

### 5.2 核心型別

**User**

```
關鍵欄位：
  id, displayName, avatarURL, bio
  phoneNumberHash（nullable，MVP 不用，為未來通訊錄匹配預留）
  friendship（與當前登入用戶的關係：isFriend / isPending / since）
  activeBroadcast（隱私控制：非好友且非 PUBLIC 廣播時為 null）
  canBroadcastAt（帳號年齡限制：新帳號 24h 內不能廣播）
```

**Broadcast**

```
關鍵欄位：
  id, player, location, radius, status（ACTIVE | STOPPED）
  startedAt, expiresAt
  distanceMeters（計算欄位，依 viewer 位置計算）
  isFriend（計算欄位）

注意：v2.0 移除 PAUSED 狀態，只有 ACTIVE / STOPPED
```

**Room（重點修訂欄位）**

```
關鍵欄位：
  id, name, host, status（WAITING | FULL | PLAYING | CLOSED）
  placeName（用戶輸入的場地名稱，如「我家」「XX 棋牌室」）
  location（可見性依 status 決定，見下方規則）
  gameRule（TAIWAN_MAHJONG | THREE_PLAYER | NATIONAL_STANDARD）
  isPublic（true=開放陌生人加入，false=僅好友）
  seats（[4]Seat，position 0-3）
  friendsInRoom（計算欄位，在這個 Room 的好友列表）
  hasFriend（計算欄位，是否有好友在此 Room）
  distanceMeters（計算欄位）

Room 地點可見性規則（Resolver 層實作）：
  status = WAITING → location 回傳模糊座標（±150m 偏移）+ placeName
  status = FULL / PLAYING → location 回傳精確座標 + placeName
  → 這樣設計：加入前保護 Host 隱私，到齊後才讓成員知道精確地點
```

**Subscription Events**

```
PlayerUpdate（nearbyPlayerUpdates / friendBroadcastEvents）：
  player, eventType, location, room
  isFriend, priority（好友=1，陌生人=10，client 端用於排序和 UI 差異化）

RoomUpdate（roomUpdated）：
  room, eventType（PLAYER_JOINED | PLAYER_LEFT | ROOM_FULL | ROOM_DISSOLVED | HOST_CHANGED）
  affectedPlayer
```

### 5.3 API 分類清單

**Query**：

| 名稱 | 說明 | 快取策略 |
|------|------|----------|
| `me` | 當前用戶 | No-cache |
| `nearbyBroadcasts(location, radiusKm)` | 附近廣播列表 | No-cache（即時資料）|
| `nearbyRooms(location, radiusKm, status)` | 附近 Room | No-cache |
| `activeFriendBroadcasts` | 正在廣播的好友列表 | No-cache |
| `room(id)` | Room 詳情 | Short TTL（5s）|
| `friends(first, after)` | 好友列表 | Redis Cache（10 min）|
| `myActiveBroadcast` | 我的當前廣播 | No-cache |
| `myCurrentRoom` | 我的當前 Room | No-cache |

**Mutation**：

| 分類 | Mutation | 說明 |
|------|----------|------|
| Broadcast | `startBroadcast` `updateLocation` `stopBroadcast` `heartbeat` | 廣播生命週期 |
| Room | `createRoom` `joinRoom` `leaveRoom` `dissolveRoom` `kickPlayer` `transferHost` `updateRoomSettings` | Room 生命週期 |
| Social | `sendFriendRequest` `acceptFriendRequest` `rejectFriendRequest` `removeFriend` `blockUser` | 社交關係 |
| Profile | `updateProfile` `uploadAvatar` | 個人資料 |
| Account | `refreshToken` `logout` `deleteAccount` | 帳號管理 |

**Subscription**：

| 名稱 | 說明 | 優先級 |
|------|------|--------|
| `nearbyPlayerUpdates(location, radiusKm)` | 附近玩家動態（雙 channel 設計）| Core |
| `friendBroadcastEvents` | 好友廣播事件（立即推，不 batch）| Core |
| `roomUpdated(roomID)` | Room 狀態更新 | Core |
| `friendRequestReceived` | 好友請求通知 | Secondary |

### 5.4 Error Code 規格

```
UNAUTHENTICATED        - 未登入或 Token 過期
FORBIDDEN              - 無權限（如非 Host 呼叫 dissolveRoom）
NOT_FOUND              - 資源不存在
BROADCAST_ALREADY_ACTIVE - 已有進行中廣播
BROADCAST_AGE_RESTRICTED - 帳號未滿 24h，不能廣播
ROOM_FULL              - Room 已滿
ROOM_NOT_JOINABLE      - Room 狀態不允許加入
ALREADY_IN_ROOM        - 已在另一個 Room
FRIEND_LIMIT_EXCEEDED  - 好友數超過 200 人上限
RATE_LIMITED           - 請求頻率超限
INTERNAL_ERROR         - 內部錯誤（不暴露細節）
```

---

## 6. 後端服務架構

### 6.1 服務職責劃分

**GraphQL Gateway**

- 唯一的對外入口
- 負責：Auth middleware、Rate limit、Schema validation、Subscription Hub
- 不包含業務邏輯，只做轉發和聚合
- Subscription resolver 是例外：好友優先推送的雙 channel 邏輯住在這裡

**Discovery Service**

- 核心職責：廣播的 CRUD、GeoIndex 操作、fan-out 觸發
- 關鍵設計：
  - **Broadcast TTL 管理**：Redis Key `broadcast:ttl:{playerID}`，TTL 10 分鐘。Client heartbeat 更新。Redis Keyspace Notification 監聽過期，觸發 StopBroadcast
  - **Location Buffer**：批次寫入歷史位置，避免直接打 DB。Buffer size 上限 1,000，flush interval 30 秒
  - **Fan-out Worker Pool**：最多 50 個 goroutine 並發 publish，避免大量好友時 goroutine 暴增

**Room Service**

- 核心職責：Room lifecycle、Seat 管理、RoomFull 觸發
- 關鍵設計：
  - Room 狀態轉移由 Domain Entity 控制（不在 Service 層寫 if/else）
  - RoomFull 發生時，同步觸發所有成員的 BroadcastStopped
  - Room 地點模糊化在 GraphQL Resolver 層，不在 Service 層（Service 永遠傳精確座標，Resolver 依 status 決定是否模糊化）

**Social Service**

- 核心職責：好友關係 CRUD、封鎖、好友 cache 維護
- 關鍵設計：
  - 好友列表 Redis Cache（`friends:{userID}` Set，TTL 10 分鐘）
  - 加/刪好友時主動 invalidate cache（DEL key）
  - 封鎖後：fan-out 過濾，雙向不可見

**Notification Service**（Notification BC）

- 核心職責：消費來自各 BC 的 Domain Event，決定是否送 FCM / In-App 通知
- 設計：Event-driven，訂閱 Pub/Sub 的 `notification:push:{userID}` channel
- P1 通知：Room 有人加入（→ Host）、RoomFull（→ 所有成員）
- P2 通知：好友廣播開始、好友請求

### 6.2 Graceful Shutdown 設計原則

**WebSocket 連線的 Rolling Update 問題**是 production 最容易踩的坑。設計要點：

```
K8s Rolling Update 流程：
  preStop hook：sleep 30s（讓 LB 把新流量切到新 pod）
  terminationGracePeriodSeconds：60s

  Shutdown 順序：
  1. 停止接受新連線（HTTP server shutdown）
  2. 廣播「server 即將重啟」給所有 Subscription client
     → Client 收到後立即觸發 reconnect（連到新 pod）
  3. 等待所有 Subscription goroutine 結束（最多 30s）
  4. Flush Location Buffer（同步寫入剩餘資料）
  5. 關閉 Redis / DB 連線池

Client 端（Flutter）必須實作 exponential backoff reconnect：
  1s → 2s → 4s → 8s → ... → 最大 60s
  重連成功後：重新 pull nearbyBroadcasts snapshot 補齊斷線期間資料
```

### 6.3 帳號年齡限制實作

```
設計：User entity 加 canBroadcastAt = created_at + 24h

觸發點（Server-side check）：
  startBroadcast、createRoom、sendFriendRequest

回傳錯誤碼：BROADCAST_AGE_RESTRICTED

用途：降低批量假帳號廣播效果

Client 端 UX：
  顯示「帳號剛建立，明天就可以開始找牌友了！」
  倒計時顯示剩餘時間
```

### 6.4 封鎖機制在 Fan-out 的影響

```
封鎖關係影響的兩個層面：

1. Query 層（nearbyBroadcasts / nearbyRooms）：
   SQL 加入 NOT EXISTS (SELECT 1 FROM blocked_users WHERE ...)
   → A 封鎖 B：A 的查詢不返回 B，B 的查詢不返回 A

2. Subscription 層（fan-out 時過濾）：
   Fan-out 前 check 封鎖列表，被封鎖方不 publish
   → 封鎖列表 Cache（Redis Set: blocked:{userID}，TTL 1h）
   → blockUser 時主動 invalidate

注意：
  封鎖是靜默的，被封鎖方無感知（API 不報錯，只是對方「消失」）
  封鎖後，歷史廣播記錄仍存在但不可見（Query 層過濾）
```

---

## 7. Flutter 客戶端架構

### 7.1 技術棧選型

| 類別 | 選擇 | 選擇理由 |
|------|------|----------|
| GraphQL Client | `ferry` + `gql_websocket_link` | graphql-ws protocol，reconnect 穩定，type-safe code gen |
| 狀態管理 | `riverpod` 2.x | StreamProvider 直接接 GraphQL Subscription，與 ferry 整合自然 |
| 地圖 | `flutter_map` + OSM tiles | Marker 數量無上限，效能比 Google Maps SDK 好，無 API 費用 |
| 定位 | `geolocator` | 跨平台，支援 iOS/Android background mode |
| 本地快取 | `hive` | 好友列表、用戶資料的離線快取 |
| 推播通知 | `firebase_messaging` | FCM 標準整合 |
| 錯誤追蹤 | `sentry_flutter` | Crash 自動上報 |
| Analytics | `firebase_analytics` | 用戶行為埋點（見 Section 2.4 事件清單）|
| 圖片快取 | `cached_network_image` | Avatar 快取 |

### 7.2 Navigation 架構

```
App Navigation（GoRouter）：

  /onboarding          → OnboardingFlow（首次啟動，3 頁教學）
  /login               → LoginPage（Apple / Google）
  /setup-profile       → ProfileSetupPage（第一次登入後）
  /                    → MainShell（底部 TabBar）
    /map               → MapPage（主地圖）
      /broadcast       → BroadcastSettingsSheet（底部彈出）
      /player/:id      → PlayerProfileSheet（底部彈出）
      /room/:id        → RoomDetailPage
    /friends           → FriendsPage（好友列表 + 動態）
    /profile           → ProfilePage
  /room/create         → CreateRoomPage
  /room/:id/full       → RoomFullPage（4 人到齊後的導引頁）

注意：
  空狀態是 /map 的 overlay，不是獨立路由
  Onboarding 完成後不再出現（SharedPreferences 記錄）
```

### 7.3 狀態管理設計

```
Riverpod Provider 架構：

  Infrastructure 層：
    graphQLClientProvider      → Ferry GraphQL Client（Singleton）
    locationServiceProvider    → Geolocator wrapper
    fcmTokenProvider           → FCM token 管理

  Feature 層：

    Discovery：
      currentLocationProvider   → 當前用戶位置（Stream from Geolocator）
      nearbyBroadcastsProvider  → Subscription stream（雙 channel）
      nearbyPlayersMapProvider  → 轉換為地圖 Marker 列表（好友優先排序）
      myActiveBroadcastProvider → 我的廣播狀態

    Room：
      nearbyRoomsProvider       → 附近 WAITING Room 列表
      currentRoomProvider       → 我目前所在的 Room
      roomDetailProvider(id)    → 特定 Room 詳情 + roomUpdated Subscription

    Social：
      friendsProvider           → 好友列表（Hive cache + GraphQL）
      activeFriendBroadcastsProvider → 正在廣播的好友
      friendRequestsProvider    → 待處理好友請求

優先級排序邏輯（在 nearbyPlayersMapProvider）：
  好友（isFriend=true, priority=1）→ 地圖頂層，永遠顯示，不 cluster
  陌生人（isFriend=false, priority=10）→ 地圖底層，zoom < 12 時 cluster
```

### 7.4 地圖效能設計

```
問題：大量 Marker 更新（好友 + 陌生人）在 60fps 下需要 <16ms per frame

分層渲染策略：
  Layer 1（底層）：Tile Layer（OSM 地圖）
  Layer 2（中層）：陌生人 MarkerClusterLayer（自動合併，zoom 控制）
  Layer 3（頂層）：好友 MarkerLayer（永遠顯示個人頭像，有動畫）

更新策略：
  好友位置更新 → 立即 setState（<100ms 視覺反應）
  陌生人位置更新 → 500ms debounce 後批次 setState（避免過多重繪）

Marker 動畫：
  好友上線：Scale 彈跳動畫（0.5→1.0，300ms elastic curve）
  好友離線：Fade out（200ms）
  陌生人：無動畫（節省效能）
```

### 7.5 定位策略（iOS / Android 差異）

```
Foreground（App 在前景）：
  iOS + Android：高精度，每 5 秒或移動 30m 觸發（取先到者）
  → 呼叫 updateLocation mutation

Background（App 在背景）：
  iOS：BGAppRefreshTask（最低 15 分鐘一次，系統決定頻率）
       + Significant Location Change（移動約 500m 觸發）
       → App Store 審查需要說明「為什麼需要背景定位」

  Android：WorkManager 定期任務（每 60 秒）
           + Android 13 以上需要 POST_NOTIFICATIONS 權限

電量優化：
  靜止不動時：Significant change threshold 50m，不觸發 API
  進入 Room 後：停止定位（廣播已停止，不需要更新位置）
  廣播停止後：降為低頻定位（每 5 分鐘，只更新 UI 自身位置）

關鍵問題（Ben 提出，Chen 確認）：
  Q：iOS 背景定位被系統殺死，廣播 TTL 10 分鐘，用戶最久會「假性存在」10 分鐘
  A：可接受，這是明確的 trade-off，在 UI 上顯示「最後更新時間」讓用戶知道
```

### 7.6 離線與重連策略

```
離線場景：
  WebSocket 斷線 → ferry 自動重連（exponential backoff 1s/2s/4s...60s）
  重連成功後：
    1. re-subscribe nearbyPlayerUpdates（Server 重新開始推送）
    2. 主動 refetch nearbyBroadcasts（補齊斷線期間的 snapshot）
    3. 顯示 "已重新連線" toast（1.5 秒後消失）

網路切換（WiFi → 4G）：
  同上，ferry 偵測到 WebSocket 斷線後自動處理

Hive 本地快取：
  好友列表：寫入 Hive，離線時仍可瀏覽（不可更新）
  用戶 Profile：寫入 Hive，避免重新打開 App 時閃白
  廣播狀態：不快取（即時資料，離線無意義）
```

---

## 8. 資料層設計

### 8.1 PostgreSQL Schema 重點

**Schema 設計原則**：

- 所有時間欄位使用 `TIMESTAMPTZ`（帶時區），不用 `TIMESTAMP`
- UUID 主鍵（`uuid_generate_v4()`），不用 auto-increment（分散式環境友好）
- Soft delete：`deleted_at TIMESTAMPTZ`，不實際刪除（GDPR 30 天後 hard delete）
- 不變量在 DB 層也要有 constraint（不只靠 application 層）

**關鍵 Constraint 設計**：

```
broadcasts 表：
  EXCLUDE USING gist(player_id WITH =) WHERE (status = 'ACTIVE')
  → DB 層保證同一 Player 只有一個 ACTIVE 廣播（application 層的 check 可能有 race）

room_seats 表：
  EXCLUDE USING btree(player_id WITH =) WHERE (player_id IS NOT NULL AND left_at IS NULL)
  → DB 層保證同一 Player 不能同時在兩個 Room

friendships 表：
  CHECK (user_id_a < user_id_b) + UNIQUE (user_id_a, user_id_b)
  → 確保好友關係只存一筆，(A,B) 和 (B,A) 視為同一條記錄
```

**Room 相關表設計要點**：

```
rooms 表新增欄位（v2.0）：
  place_name  VARCHAR(100)    -- 用戶輸入的場地名稱
  game_rule   VARCHAR(30)     -- TAIWAN_MAHJONG / THREE_PLAYER / NATIONAL_STANDARD
  is_public   BOOLEAN DEFAULT TRUE  -- 是否開放陌生人加入
```

**Location History（TimescaleDB Hypertable）**：

```
設計要點：
  chunk_time_interval = 1 天（每天一個 chunk）
  retention_policy = 30 天（自動刪除舊資料）
  compression_policy = 7 天（超過 7 天自動壓縮，節省儲存）

不直接寫入，透過 Location Buffer 批次寫入：
  Buffer 上限：1,000 筆
  Flush interval：30 秒
  Flush 失敗：暫存 retry queue（最多 3 次），不影響主流程
```

### 8.2 Redis Key 設計

```
=== 即時位置（GeoSet）===
KEY: geo:broadcasts
TYPE: Sorted Set（Redis GeoSet）
VALUE: {playerID} 對應座標
TTL: 無（應用層控制，stopBroadcast 時 ZREM）
用途: GeoRadius 查詢附近廣播

=== 廣播 TTL 心跳 ===
KEY: broadcast:ttl:{playerID}
TYPE: String，VALUE: "1"
TTL: 10 分鐘（heartbeat 更新）
觸發: Redis Keyspace Notification 過期事件 → 自動 StopBroadcast

=== 好友列表 Cache ===
KEY: friends:{userID}
TYPE: Set，VALUE: {friendID1, friendID2, ...}
TTL: 10 分鐘
Invalidate: 加/刪好友時 DEL（Write-through 策略）

=== 封鎖列表 Cache ===
KEY: blocked:{userID}
TYPE: Set，VALUE: {blockedUserID1, ...}
TTL: 1 小時
Invalidate: blockUser 時 DEL

=== JWT Blacklist（登出）===
KEY: jwt:blacklist:{jti}
TYPE: String，VALUE: "1"
TTL: 等於 JWT accessToken 剩餘有效時間

=== 帳號廣播解鎖時間（可選 Cache）===
KEY: user:can-broadcast:{userID}
TYPE: String，VALUE: {timestamp}
TTL: 25 小時（帳號建立後 25h 後過期，讓 DB 成為 source of truth）

=== Rate Limit ===
KEY: rate:{userID}:{action}:{window_minute}
TYPE: String（counter）
TTL: 2 分鐘（sliding window）
```

### 8.3 資料一致性策略

```
GeoIndex vs DB 一致性問題：
  正常流程：DB 更新成功 → GeoIndex 更新
  GeoIndex 更新失敗時：記錄錯誤 metric，降級處理（不回滾 DB）

  Reconciliation Job（每分鐘跑一次）：
    SELECT player_id FROM broadcasts WHERE status='ACTIVE'
    比對 Redis GeoSet，補齊遺漏的 player_id
    → 防止 GeoIndex 和 DB 長期不一致

好友 Cache vs DB 一致性：
  Cache-aside 策略：
    Read：先讀 Redis，miss 時讀 DB 再回寫 Cache
    Write：先寫 DB，成功後 invalidate Cache（不做 write-through，避免 race）

  最終一致性：Cache TTL 10 分鐘，最壞情況用戶看到 10 分鐘前的好友列表
  → 對本業務可接受（加好友不是高頻操作）
```

---

## 9. 基礎設施

### 9.1 MVP 基礎設施（Week 1-10）

```
精簡原則：MVP 基礎設施以「能跑、能監控、能快速修復」為目標，
          不以「高可用、高彈性」為目標（那是 v1.1 的事）

計算：
  GraphQL Gateway：2 pod（rolling update 時保證不斷線）
  Discovery Service：2 pod
  Room Service：1 pod（Room 操作頻率低）
  Social Service：1 pod
  Notification Service：1 pod

資料庫：
  PostgreSQL：單一節點（Primary only）
  Redis：Sentinel 模式（1 Primary + 2 Replica，自動 failover）

部署：
  K8s（GKE 或 EKS）
  Rolling Deploy（非 Canary，MVP 流量小，風險可接受）
```

### 9.2 Scale 觸發條件（v1.1）

以下基礎設施升級在達到條件時執行，不提前做：

| 升級項目 | 觸發條件 | 預估時程 |
|----------|----------|----------|
| NATS 替換 Redis Pub/Sub | DAU > 5,000 或 fan-out 延遲 p99 > 1s | 2 週（Publisher Interface 已準備好）|
| PostgreSQL Read Replica | DB CPU > 70% 持續 30 分鐘 | 1 週 |
| Redis Cluster | Redis Memory > 60% 或 QPS > 100,000 | 1 週 |
| Canary Deploy | 有重大 feature 需要灰度驗證 | 按需 |
| HPA 自動擴縮 | WebSocket 連線 > 5,000/pod | 1 週（Metric 先埋好）|

### 9.3 CI/CD Pipeline

```
流程：
  PR 合併 →
    ① golangci-lint + dart analyze
    ② go test -race ./... + flutter test
    ③ Integration test（Testcontainers：PostgreSQL + Redis）
    ④ Build Docker image（multi-stage, distroless）
    ⑤ Trivy 安全掃描
    ⑥ Push to Container Registry
  
  Staging 自動部署 →
    ① E2E smoke test
    ② k6 基本負載測試（目標 QPS 的 50%）
  
  Production 手動 approve →
    ① Rolling Deploy
    ② 自動 rollback 觸發條件：error rate > 1% 或 p99 > 2s（5 分鐘觀察窗）

App 發布：
  iOS：TestFlight（Beta）→ App Store Connect（Production）
  Android：Firebase App Distribution（Beta）→ Play Store（Production）
  注意：App Store 審查 3-7 工作天，TestFlight 審查 2-3 工作天，排程要提前
```

---

## 10. 可觀測性

### 10.1 Metrics 設計原則

> 所有 Metric 都要在 Phase 0 就埋好，不是最後才補。可觀測性是品質的一部分，不是功能。

**必須有的 Metric 分類**：

```
業務指標（Business Metrics）：
  active_broadcasts_total         當前活躍廣播數（Gauge）
  room_created_total              Room 建立數（Counter）
  room_full_total                 成功配對數（Counter，北極星指標的數據來源）
  broadcast_duration_minutes      廣播持續時間（Histogram）
  time_to_room_full_minutes       建房到滿員時間（Histogram）

技術指標（Technical Metrics）：
  graphql_request_duration_ms{operation}      API 延遲（Histogram）
  graphql_errors_total{code}                  錯誤數（Counter）
  websocket_connections_total                 WS 連線數（Gauge）
  subscription_events_pushed_total{type}      推送事件數（Counter）
  subscription_events_dropped_total{reason}   Drop 事件數（Counter）
  fan_out_duration_ms                         Fan-out 延遲（Histogram）
  fan_out_friend_count                        每次 fan-out 好友數（Histogram）
  location_buffer_size                        批次 Buffer 大小（Gauge）
  redis_command_duration_ms{command}          Redis 指令延遲（Histogram）
```

### 10.2 關鍵 Alert 規則

| Alert | 條件 | 嚴重度 | 說明 |
|-------|------|--------|------|
| HighErrorRate | error rate > 1%，持續 2 分鐘 | Critical | 立即 PagerDuty |
| WebSocketDrop | WS 連線數 5 分鐘內降 30% | Critical | 可能有 crash |
| FanOutSlow | fan-out p99 > 2s，持續 5 分鐘 | Warning | 好友推送變慢 |
| LocationBufferGrowing | buffer > 1,000 持續 3 分鐘 | Warning | DB 寫入慢 |
| RedisPubSubLag | Pub/Sub 積壓 > 5,000 | Warning | 接近 Redis 上限，準備換 NATS |
| HighCrashRate | Sentry crash rate > 1% | Critical | Flutter crash |

### 10.3 Distributed Tracing

```
使用 OpenTelemetry（OTEL）

關鍵 Trace 路徑示例（startBroadcast）：
  GraphQL.Mutation.startBroadcast
    └── Auth.ValidateJWT
    └── DiscoveryService.StartBroadcast（gRPC）
          └── BroadcastRepo.FindByPlayerID（PostgreSQL）
          └── BroadcastRepo.Save（PostgreSQL）
          └── GeoIndex.Add（Redis）
          └── FanOut.Async（goroutine，non-blocking）
                └── SocialService.GetFriends（gRPC）
                └── Publisher.Publish × N（Redis）

目標：每個 Mutation 的 E2E trace 可以在 Jaeger/Grafana Tempo 查詢
     能清楚看到每個 span 的延遲貢獻，定位慢點
```

### 10.4 Grafana Dashboard 規劃

```
Dashboard 1：Business Overview
  - 當前活躍廣播數（Big Number）
  - 過去 24h 成功配對次數（Line chart）
  - 好友 vs 陌生人配對比例（Pie chart）
  - 平均等待配對時間（Big Number）

Dashboard 2：System Health
  - API p50/p95/p99 latency（Line chart）
  - Error rate（Line chart）
  - WebSocket 連線數（Gauge）
  - Fan-out latency distribution（Heatmap）
  - Redis Pub/Sub 積壓（Line chart，有 NATS 替換警戒線）

Dashboard 3：Infrastructure
  - Pod CPU / Memory（Heatmap）
  - DB connections（Line chart）
  - Location write throughput（Line chart）
  - Redis memory usage（Line chart）
```

---

## 11. 安全與濫用防護

### 11.1 Authentication 設計

```
OAuth 流程：
  Apple Sign-In / Google Sign-In → Auth Service 驗證 → JWT

JWT 設計：
  Algorithm：RS256（非對稱，各 Service 只需 public key 驗證）
  Access Token TTL：15 分鐘
  Refresh Token TTL：30 天（Rotation：每次 refresh 產生新 refresh token）
  Refresh Token 儲存：Server 只存 SHA-256 hash，不存明文

WebSocket Auth（重要）：
  不在 URL query string 帶 token（會出現在 server log）
  使用 graphql-ws protocol 的 connection_init message：
    { "type": "connection_init", "payload": { "Authorization": "Bearer {token}" } }
```

### 11.2 Rate Limiting 規格

| Action | 上限 | 窗口 | 說明 |
|--------|------|------|------|
| `startBroadcast` | 5 次 | 1 分鐘 | 防止反覆開關廣播 |
| `updateLocation` | 60 次 | 1 分鐘 | 每秒最多 1 次 |
| `heartbeat` | 20 次 | 1 分鐘 | 5 分鐘一次就夠 |
| `createRoom` | 3 次 | 1 分鐘 | 防止垃圾 Room |
| `joinRoom` | 10 次 | 1 分鐘 | |
| `sendFriendRequest` | 20 次 | 1 小時 | 防止大量騷擾請求 |
| `searchUsers` | 30 次 | 1 分鐘 | |

### 11.3 濫用防護

**帳號年齡限制（新帳號前 24 小時）**：

| 功能 | 新帳號（< 24h）| 正常帳號 |
|------|----------------|----------|
| 查看附近廣播 | ✅ | ✅ |
| 加入 Room | ✅ | ✅ |
| 開始廣播 | ❌ | ✅ |
| 建立 Room | ❌ | ✅ |
| 傳送好友請求 | ❌ | ✅ |

**封鎖機制行為規格**：

| 情境 | 行為 |
|------|------|
| A 封鎖 B | A/B 雙方搜尋結果互相不可見 |
| 封鎖後通知 | 被封鎖方無感知（對方像是消失了）|
| 封鎖後歷史位置 | Query 層過濾，不可見 |
| 已在同一 Room | 封鎖不影響當前 Room（避免對局被打斷），下次不再同 Room |

**Bot 偵測（基礎版）**：

```
規則 1：同一 IP 在 1 小時內超過 3 個帳號 startBroadcast → 觸發人工審核標記
規則 2：位置跳變（兩次更新間距 > 物理上可能的移動距離）→ 暫停廣播並記錄
規則 3：新帳號 24h 限制（如上）→ 大幅降低批量假帳號廣播效果
未來（v1.1）：SMS Phone Number 驗證
```

### 11.4 座標隱私規格

```
陌生人看到的廣播位置：±150m 隨機偏移（保護到街道級別，不到門牌）
Room 地點可見性：
  WAITING → 模糊座標 + placeName
  FULL 後 → 精確座標 + placeName（成員才能看到精確地點）

實作位置：GraphQL Resolver 層（Service 層永遠傳精確座標）
```

### 11.5 台灣個資法合規要點

```
用戶同意：
  首次登入時顯示隱私政策 + 使用條款（需要明確點擊同意）
  位置資料使用說明：「用於顯示附近牌友，不會出售給第三方」

資料刪除（deleteAccount Mutation）：
  立即：soft delete（users.deleted_at = NOW()）
  立即：停止廣播、離開 Room、Redis 資料清除
  30 天後：hard delete（排程 job 定期執行）

App Store Privacy 標籤（陳列必填）：
  精確位置：是，用於廣播功能
  用戶 ID：是，用於帳號識別
  使用資料：是，用於分析（Firebase Analytics）
  聯絡人：否（MVP 不收集，未來通訊錄匹配再更新）
```

---

## 12. MVP 範圍定義

### 12.1 MVP 功能清單（v2.0 修訂版）

**P0（阻斷發布）**：

| 功能 | 說明 |
|------|------|
| OAuth 登入 | Apple + Google |
| 個人資料設定 | displayName（必填）、avatar（選填）|
| 開始廣播 | 帶位置、固定 5km 範圍、PUBLIC 可見 |
| 更新位置 | Foreground 高頻，Background 低頻 |
| 停止廣播 | 手動 + TTL 自動過期 |
| 廣播心跳 | 每 5 分鐘 heartbeat，防止 TTL 過期 |
| 查看附近廣播 | GeoRadius 5km，好友優先排序 |
| Subscription 即時推送 | 雙 channel 設計（好友立即，陌生人 batch）|
| 建立 Room | 填名稱、場地名稱、選擇規則、公開/僅好友 |
| 加入 Room | 4 人制，滿員不可加入 |
| 離開 Room | 含 Host 離開自動解散 |
| RoomFull 通知（FCM）| **v2.0 升為 P0**：Room 有人加入（Host）、Room 滿員（所有成員）|
| 帳號年齡限制 | 新帳號 24h 功能限制 |
| 封鎖用戶 | 雙向不可見 |

**P1（MVP 應包含）**：

| 功能 | 說明 |
|------|------|
| 好友系統 | 加好友、接受/拒絕、好友列表 |
| 好友優先推送 | friend channel，立即 push |
| 好友動態列表 | 正在廣播的好友列表（非地圖視圖）|

**P2（v1.1 加入）**：

| 功能 | 說明 |
|------|------|
| FCM：好友廣播通知 | 好友廣播開始，送通知 |
| FCM：好友請求通知 | 收到/接受好友請求 |
| 廣播可見性選擇 | FRIENDS_ONLY 選項 |

**不在 MVP**：

| 功能 | 理由 |
|------|------|
| 聊天功能 | 獨立 BC，估計 3 週工程，調至 M2 |
| 用戶評分系統 | 需要配對量，調至 M3 |
| 通訊錄匹配 | `phoneNumberHash` 欄位預留，功能調至 M2 |
| 麻將規則篩選 UI | 規則欄位 DB 已有，UI 調至 M2 |
| 廣播歷史查看 | TimescaleDB 有存，UI 調至 M2 |

---

## 13. 開發里程碑

### 13.1 Phase 0：環境與對焦（Week 1）

**目標**：所有人共識對齊，基礎建設就緒

| 任務 | 負責人 | 交付物 |
|------|--------|--------|
| 業務假設與 PM 最終確認 | All | 本文件 Section 2.2 確認版 |
| ADR 撰寫（v2.0 版本）| Alex + Ben | 見 Section 15 |
| docker-compose 本地環境 | Ben | PostgreSQL + Redis + 全服務可跑 |
| CI Pipeline 骨架 | Ben | PR → lint → test → build 跑通 |
| gqlgen + Wire 專案骨架 | Alex | schema.graphql + generated code |
| DB Migration 工具設定 | Alex | golang-migrate，initial schema |
| Flutter 專案初始化 | Chen | ferry + riverpod + flutter_map 跑通 |
| Prometheus + Grafana 基礎 | Ben | 第一個 metric 被收到 |
| OTEL Collector 設定 | Ben | 第一個 trace 可查詢 |

**完成標準**：`docker-compose up` 後，一個 hello-world GraphQL query 能跑通，Grafana 上看到第一個 metric。

---

### 13.2 Phase 1a：Identity + Broadcast 核心（Week 2-3）

**目標**：端到端廣播流程可跑通

| 任務 | 負責人 | 驗收標準 |
|------|--------|----------|
| Auth Service（JWT + OAuth）| Alex | Apple/Google OAuth 完整測試 |
| Broadcast Domain Entity + 不變量 | Alex | 所有 constraint 有 unit test |
| Redis GeoIndex（GeoAdd / GeoRadius）| Alex | 邊界案例（5 個相鄰格子）有測試 |
| startBroadcast / stopBroadcast | Alex | E2E 測試：A 廣播，B 查到 |
| updateLocation + Significant Change Filter | Alex | 50m 以下不觸發，有 unit test |
| 帳號年齡限制邏輯 | Alex | 新帳號呼叫 startBroadcast 得到 BROADCAST_AGE_RESTRICTED |
| Broadcast TTL + Keyspace Notification | Alex | 不發 heartbeat，10 分鐘後廣播自動停止 |
| Location Buffer + 批次寫入 | Ben | Testcontainers 模擬 1,000 wps 通過 |
| Redis Pub/Sub Publisher | Ben | Publish 延遲 < 10ms，有測試 |
| Flutter：OAuth 登入頁面 | Chen | Apple / Google 登入成功，JWT 存入 Secure Storage |
| Flutter：主地圖頁面骨架 | Chen | 地圖顯示，定位取得成功 |
| Flutter：廣播開關 + nearbyBroadcasts | Chen | 開始廣播，地圖上看到自己的 pin |

---

### 13.3 Phase 1b：Subscription 即時推送（Week 4）

**目標**：A 廣播，B 立即在地圖上看到

| 任務 | 負責人 | 驗收標準 |
|------|--------|----------|
| Fan-out（Geo channel publish）| Alex | A startBroadcast，B 的 Subscription 在 < 1s 收到 |
| Geohash 鄰格訂閱（邊界問題）| Alex | 跨格子邊界的玩家不漏掉 |
| Subscription Resolver（陌生人 batch）| Alex | 多個陌生人事件 500ms 內 batch，非逐一推送 |
| Back-pressure 機制 | Alex | Slow client buffer 滿時 drop 陌生人事件，不 OOM |
| Flutter：StreamProvider 接 Subscription | Chen | Subscription events 即時顯示在地圖 |
| Flutter：Marker 更新動畫 | Chen | 新 pin 出現有彈跳動畫，消失有 fade out |
| Flutter：Reconnect 機制 | Chen | 模擬斷線，自動重連，重連後 refetch snapshot |

---

### 13.4 Phase 1c：好友系統 + 優先推送（Week 5）

**目標**：好友廣播立即推送，陌生人 batch 推送

| 任務 | 負責人 | 驗收標準 |
|------|--------|----------|
| Social BC Domain + Friendship Repo | Alex | 好友 CRUD unit test 通過 |
| 好友 CRUD Mutation | Alex | 加友/接受/拒絕 E2E 測試 |
| 好友列表 Redis Cache | Alex | Cache hit rate > 90% in load test |
| 封鎖機制（Query + Fan-out 過濾）| Alex | A 封鎖 B 後，互相從對方列表消失 |
| Friend Channel Fan-out | Alex | 好友事件發到 `broadcast:friend:{friendID}` |
| Subscription Resolver 雙 Channel 設計 | Alex | 好友事件 < 100ms，陌生人 batch 500ms |
| 好友 Cache Invalidation | Alex | 加好友後 10 分鐘內 Subscription 反映新好友 |
| Flutter：好友列表頁面 | Chen | 加好友、查看好友廣播狀態 |
| Flutter：好友 Marker 優先顯示 | Chen | 好友 Marker 在頂層，有大頭貼，不 cluster |
| Flutter：好友動態列表 | Chen | 正在廣播的好友列表 Tab |

---

### 13.5 Phase 1d：Room 系統（Week 6-7）

**目標**：完整 4 人成局流程，含 FCM 通知

| 任務 | 負責人 | 驗收標準 |
|------|--------|----------|
| Room Domain Entity + 不變量 | Alex | 所有 State machine 邊界 unit test |
| Room CRUD Mutation（含 gameRule, isPublic, placeName）| Alex | createRoom / joinRoom / leaveRoom E2E |
| Room 地點模糊化（Resolver 層）| Alex | WAITING 回傳模糊座標，FULL 後精確 |
| RoomFull → BroadcastStopped × 4 | Alex | 4 人到齊，廣播全部停止 |
| Room Subscription（roomUpdated）| Alex | 每個 Seat 更新即時推送 |
| Notification Service 基礎 | Ben | 訂閱 Pub/Sub notification channel |
| FCM 整合（P1 通知：加入 Room、RoomFull）| Ben | Host 手機收到「有人加入 Room」FCM |
| nearbyRooms Query | Alex | 附近 WAITING Room 查詢，isPublic 過濾 |
| 好友 Room 過濾（非好友不可見私人 Room）| Alex | isPublic=false 時非好友查不到 |
| Flutter：Room 列表 + 建立頁面 | Chen | 選場地名稱、規則、公開/私人 |
| Flutter：Room 詳情（4 個座位）| Chen | 即時看到其他人加入 |
| Flutter：RoomFull 導引頁面 | Chen | 顯示場地名稱 + 精確座標地圖 + 導航按鈕 |
| Flutter：FCM Token 管理 | Chen | FCM Token 上傳到 Server，接收 push 通知 |

---

### 13.6 Phase 2：Production Hardening（Week 8-9）

**目標**：能安全上線，能監控，能快速恢復

| 任務 | 負責人 | 驗收標準 |
|------|--------|----------|
| Graceful Shutdown 完整流程 | Ben | SIGTERM 後 WS 連線 gracefully close，Location Buffer flush |
| WebSocket Goroutine Leak 偵測 | Ben | goroutine count 穩定，不持續增長（Prometheus 監控）|
| NATS Consumer 生命週期管理 | Ben | WS 斷線後對應 subscription goroutine 立即清理 |
| Circuit Breaker（Redis 故障降級）| Ben | Redis 不可用時廣播仍寫 DB，不 panic |
| Reconciliation Job（GeoIndex vs DB）| Ben | 每分鐘補齊 GeoIndex 和 DB 不一致 |
| k6 Load Test | Ben | p99 < 500ms，error rate < 0.1%，目標 2× MVP DAU（2,000 users）|
| Grafana Dashboard（3 個）| Ben | Business / System Health / Infra |
| Alerting 規則（6 個以上）| Ben | 模擬故障，alert 正確觸發並通知 Slack |
| Rate Limiting 完整實作 | Alex | 所有 action 的 limit 有測試 |
| JWT Blacklist（logout）| Alex | logout 後 token 在 TTL 到期前立即失效 |
| App Store Privacy 說明文件 | Chen + Sarah | Apple 審查所需文件完成 |
| Sentry 整合 | Chen | Crash 自動上報，含 user context |
| Analytics 埋點（Firebase Analytics）| Chen | Section 2.4 所有事件正確觸發 |
| 用戶錯誤提示 UI | Chen | 所有 GraphQL error code 有對應的 UI 提示 |

---

### 13.7 Phase 3：Feature Freeze + Beta（Week 10-13）

**Week 10：Feature Freeze**

```
從這一天起，不接受任何新功能 PR。
只接受：Bug fix、效能調整、UI 細節、文案修改。
```

| 任務 | 負責人 | 說明 |
|------|--------|------|
| Staging 完整 E2E 測試 | All | 模擬完整用戶旅程（場景 A + B）|
| Production 環境建立（K8s + DB + Redis）| Ben | Cloudflare + SSL |
| TestFlight Beta 送審 | Chen | Apple TestFlight（需 2-3 天審查）|
| Firebase App Distribution Beta | Chen | Android Beta |

**Week 11-12：Beta 測試（300-500 人，台北市）**

```
招募管道：PTT 麻將版、Facebook 麻將社團、工程師個人網絡

監控重點：
  - D1 / D7 Retention
  - RoomFull 次數（北極星指標）
  - Crash rate
  - 用戶反饋（Typeform 問卷）

Bug Triage：
  Critical（立即修）：Crash、資料錯誤、無法廣播
  High（72h 內修）：功能錯誤、通知不送達
  Medium（下個 Sprint）：UI 問題、效能
```

**Week 13：Beta 反饋整合**

```
如果 Beta 成功門檻達到（D1 >= 30%，首次配對率 >= 40%）→ 繼續 Week 14 正式上線
如果未達到 → PM + 工程師 Pivot 討論，重新排 Backlog
```

---

### 13.8 Phase 4：正式上線（Week 14）

| 任務 | 負責人 |
|------|--------|
| App Store 正式送審（需提前 7 天）| Chen |
| Play Store 正式發布 | Chen |
| Production 最終 smoke test | All |
| 7×24 On-call 排班啟動（輪班表見 Section 16 A07）| Ben |
| 社群宣傳（LINE 群、PTT、FB 社團）| Kevin |

---

### 13.9 Post-MVP Roadmap（Week 14+）

> 優先級基於用戶留存策略（Kevin 提議，Sarah 確認）

| 功能 | 月份 | 說明 |
|------|------|------|
| Room 內聊天 | M2 | 打完麻將約下次，NATS Streams 實作 |
| 好友限定廣播（FRIENDS_ONLY）| M2 | 降低使用門檻 |
| 麻將規則篩選 UI | M2 | DB 欄位已有，只需 UI |
| 通訊錄好友匹配 | M2 | `phoneNumberHash` 欄位已預留 |
| 廣播半徑自選 | M3 | 0.5~50km 滑桿 |
| 用戶評分系統 | M3 | 需要足夠配對量才有意義 |
| 廣播歷史查看 | M3 | TimescaleDB 已存，只需 UI |
| 配對演算法優化 | M4 | 依評分、規則偏好配對 |
| 台中/高雄擴展 | M3 | 台北密度夠後擴展 |
| 線上麻將（評估中）| M6+ | 需要獨立評估，可能是不同產品 |

---

## 14. 風險登記冊

| ID | 風險 | 可能性 | 影響 | 緩解措施 |
|----|------|--------|------|----------|
| R01 | 冷啟動：附近沒人，用戶流失 | 高 | 嚴重 | Beta 集中台北市；空狀態引導 CTA；邀請制先建密度 |
| R02 | iOS 背景定位被系統殺死 | 高 | 中 | TTL 10 分鐘給緩衝；UI 顯示「最後更新時間」|
| R03 | App Store 審查被拒（定位理由不充分）| 中 | 高 | Week 8 準備文件；陳述「找線下活動搭子」使用場景 |
| R04 | Redis Pub/Sub fan-out 到達上限 | 中（DAU 5k+）| 中 | Publisher Interface 抽象；監控 fan-out 延遲預警 |
| R05 | WebSocket Rolling Update 中斷連線 | 高 | 低 | preStop hook；Client exponential backoff reconnect |
| R06 | Geohash 邊界漏掉附近玩家 | 中 | 中 | 訂閱中心 + 8 個相鄰格子；邊界 E2E 測試 |
| R07 | Room 地點隱私洩漏 | 中 | 高 | WAITING 模糊座標；FULL 後才精確；Resolver 層控制 |
| R08 | 假帳號批量廣播騷擾 | 中 | 中 | 帳號 24h 限制；IP 偵測；人工審核標記 |
| R09 | GeoIndex 和 DB 不一致 | 低 | 中 | Reconciliation Job 每分鐘 sync |
| R10 | Beta 未達成功門檻（PMF 不成立）| 中 | 嚴重 | Week 13 Pivot 機制；保留 Post-Beta 討論窗口 |

---

## 15. ADR 架構決策記錄

### ADR-001：MVP 使用 Redis Pub/Sub，預留 NATS 替換路徑

**狀態**：Accepted（v2.0 修訂）  
**決策者**：Alex, Ben, Sarah, Kevin

**背景**：v1.0 直接選 NATS JetStream，但 MVP DAU 修正為 1,000 後，Fan-out 量 ~8,000 pub/s，Redis Pub/Sub 可以處理。

**決策**：
- MVP 使用 Redis Pub/Sub
- 定義 `Publisher Interface`（Publish / Subscribe），不讓 application code 直接依賴 Redis Client
- 替換觸發條件：DAU > 5,000 或 fan-out p99 延遲 > 1s
- 替換時：只換 `RedisPublisher` → `NATSPublisher`，application code 不動

**後果（正面）**：MVP 基礎設施大幅簡化，運維成本低，學習成本低。

**後果（負面）**：成長期需要一次替換作業（預計 2 週），屆時有短暫風險窗口。

---

### ADR-002：使用 gqlgen 作為 GraphQL Framework

**狀態**：Accepted  
**決策者**：Alex

**背景**：需要強型別、code-first、支援 graphql-ws 的 Go GraphQL library。

**決策**：gqlgen。Schema-first，自動生成 Go interface，開發者實作 resolver，強型別保證。

**後果（正面）**：型別安全，IDE 支援好，subscription 實作成熟。

**後果（負面）**：Schema 修改後需要重新 generate，有一定學習曲線。

---

### ADR-003：位置歷史使用 TimescaleDB Extension

**狀態**：Accepted  
**決策者**：Alex, Ben

**背景**：位置歷史資料是典型時序資料，每天數十萬筆，需要自動 retention 和 compression。

**決策**：PostgreSQL + TimescaleDB Extension，自動 chunk、compression、retention policy。

**後果（正面）**：不需要引入獨立的時序資料庫，PostgreSQL 生態繼承，管理一致。

**後果（負面）**：PostgreSQL 需要安裝 extension，部署比純 PostgreSQL 略複雜。

---

### ADR-004：Flutter 狀態管理使用 Riverpod 2.x

**狀態**：Accepted  
**決策者**：Chen

**背景**：GraphQL subscription 返回 Dart Stream，需要與狀態管理深度整合。

**決策**：Riverpod 2.x 的 `StreamProvider` 直接消費 ferry 的 subscription stream。

**後果（正面）**：Code 量少，測試容易，hot reload 友好，與 ferry 整合自然。

**後果（負面）**：BLoC 在台灣 Flutter 社群較普及，新成員可能需要學習成本。

---

### ADR-005：WebSocket Auth 使用 connection_init message

**狀態**：Accepted  
**決策者**：Alex, Ben

**背景**：URL query string 帶 token 會出現在 server access log 和 nginx log，有洩漏風險。

**決策**：使用 graphql-ws protocol 的 `connection_init` message 傳遞 Authorization header。

**後果（正面）**：Token 不出現在任何 log，符合安全最佳實踐。

**後果（負面）**：Server 需要在 connection_init message handler 做 auth，而非 HTTP upgrade 層。

---

### ADR-006：好友優先推送使用雙 Channel 設計

**狀態**：Accepted  
**決策者**：Alex

**背景**：好友的廣播需要立即推送（< 100ms），陌生人廣播可以 batch（500ms），二者需要差異化處理。

**決策**：
- `broadcast:friend:{userID}`：好友專屬 channel，Subscription 收到後立即 push
- `broadcast:geo:{geohash}`：陌生人 channel，500ms batch 後 push
- in-memory friendSet 用於去重（防止好友事件從兩個 channel 各推一次）

**後果（正面）**：實現好友 vs 陌生人的體驗差異化，這是核心 value proposition。

**後果（負面）**：去重邏輯增加 Subscription Resolver 複雜度；friendSet 需要隨好友關係變化即時更新。

---

### ADR-007：Room 地點在 WAITING 時模糊化

**狀態**：Accepted（v2.0 新增）  
**決策者**：Alex, Sarah（PM 提出隱私需求，工程確認實作可行）

**背景**：Room 地點通常是 Host 的家，WAITING 狀態時對陌生人（潛在加入者）顯示精確地址有隱私風險。

**決策**：
- WAITING：Resolver 層對 location 加 ±150m 隨機偏移後返回。placeName 正常返回。
- FULL / PLAYING：返回精確座標。
- 實作位置：GraphQL Resolver 層，Service 層永遠傳精確座標。

**後果（正面）**：保護 Host 隱私，降低陌生人直接找上門的風險。4 人確認後才揭露精確地點，有合理的信任機制。

**後果（負面）**：WAITING 時地圖 pin 位置不精確，可能讓用戶誤判距離。（可接受，placeName 補充說明）

---

### ADR-008：帳號年齡限制（新帳號 24h 功能限制）

**狀態**：Accepted（v2.0 新增）  
**決策者**：Alex, Sarah

**背景**：批量假帳號的主要騷擾方式是大量廣播製造假訊號。

**決策**：新帳號建立後 24 小時內，不能 startBroadcast、createRoom、sendFriendRequest。

**實作**：
- `users` 表加 `can_broadcast_at TIMESTAMPTZ`（= created_at + 24h）
- Server-side check，回傳 `BROADCAST_AGE_RESTRICTED` error
- Client 顯示倒計時 UI

**後果（正面）**：大幅提高批量假帳號的攻擊成本。正常用戶只等一天，影響可接受。

**後果（負面）**：真實新用戶第一天無法廣播，可能造成流失。需要 Onboarding 說明。

---

## 16. 開放問題清單

| ID | 問題 | 影響範圍 | 截止 | 負責人 |
|----|------|----------|------|--------|
| Q01 | SLA 目標（99.9% vs 99%）？ | 部署策略、DB HA | Week 2 | Sarah → CEO |
| Q02 | 台灣個資法：位置資料保留 30 天是否合規？ | DB retention | Week 4 | Sarah（法律顧問）|
| Q03 | 付費模型啟動時間點？ | 功能優先排序 | Week 4 | Sarah → CEO |
| Q04 | Room 地點是否可完全自訂（任意座標）？ | 假地點防護問題 | Week 3 | Kevin + Alex |
| Q05 | 「好友動態」Tab 是獨立 Tab 還是主地圖 overlay？ | Flutter navigation | Week 3 | Kevin → Chen |
| Q06 | Beta 未達標時的 Pivot 方向？ | 產品方向 | Week 13 | All |
| Q07 | 線上麻將是否列入長期 Roadmap？ | 產品方向 | Week 6 | Sarah + Kevin |
| Q08 | App Store 年齡分級設定（17+）？ | App Store 送審 | Week 5 | Chen |
| Q09 | On-call 輪班表（3 個工程師如何排班）？ | 上線後保障 | Week 4 | Ben |
| Q10 | Beta 招募具體時程與渠道確認？ | Week 11 Beta 能否如期 | Week 5 | Kevin |

---

*文件版本：v2.0*  
*工程確認：Alex ✅ Ben ✅ Chen ✅*  
*PM 確認：Sarah ✅ Kevin ✅*  
*下次審查：Week 4（整合 Wireframe 後）*

*Alex · Ben · Chen · Sarah · Kevin — 2026-03-28*
