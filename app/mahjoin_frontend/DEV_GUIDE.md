# MahJoin Flutter 開發指南

> 寫給剛加入團隊的 Junior 開發者。讀完這份文件，你就能獨立新增功能或修復 Bug。  
> 閱讀順序：從上往下，不要跳章節。

---

## 目錄

1. [這個 App 在做什麼](#1-這個-app-在做什麼)
2. [技術棧一覽](#2-技術棧一覽)
3. [學習路線圖](#3-學習路線圖)
   - 3.1 Flutter Widget 基礎
   - 3.2 StatefulWidget 生命週期
   - 3.3 專案架構分層
   - 3.4 Service Singleton 模式
   - 3.5 API Client 模式
   - 3.6 WebSocket 即時更新
   - 3.7 GoRouter 導航
   - 3.8 flutter_map 地圖
   - 3.9 Geolocator 定位
   - 3.10 設計系統（Design System）
4. [新增一個功能的完整流程](#4-新增一個功能的完整流程)
5. [修 Bug 的思路](#5-修-bug-的思路)
6. [常見陷阱與注意事項](#6-常見陷阱與注意事項)

---

## 1. 這個 App 在做什麼

**MahJoin** 是一個「找麻將腳」的 App。  
使用者開啟 App 後，可以在地圖上看到附近正在尋找麻將遊戲的玩家，並建立或加入「房間」等人湊牌局。

核心功能流程：

```
登入/註冊
    ↓
地圖頁（即時看到附近玩家和房間）
    ↓
點選 Broadcast FAB → 讓別人看到你
    ↓
建立房間 or 加入房間
    ↓
等齊四人 → 開局
```

後端是一個 Go 服務，跑在 `http://localhost:8080`。  
MVP 階段沒有 JWT，所有 API 都帶 `X-User-ID` header 做身份識別。

---

## 2. 技術棧一覽

| 用途 | 套件 | 在哪裡用 |
|------|------|---------|
| UI Framework | Flutter | 整個 `lib/` |
| 路由 | `go_router` ^14 | `lib/core/router/` |
| 地圖 | `flutter_map` + OSM | `lib/features/map/` |
| HTTP | `http` | `lib/core/network/api_client.dart` |
| WebSocket | `web_socket_channel` | `lib/core/network/ws_client.dart` |
| 定位 | `geolocator` | `lib/core/location/location_service.dart` |
| 本地儲存 | `shared_preferences` | `lib/core/storage/preferences.dart` |

> ⚠️ **不使用**：Riverpod（已在 pubspec，但尚未啟用）、Ferry、GetX、BLoC。  
> 現在的狀態管理全部用 **StatefulWidget + setState**。

### 2.1 M4 品質更新（2026-04-11）

- 已加入事件去重合併策略（Map 頁面對 broadcast/room 事件做 idempotent upsert/remove）。
- 已加入 release mock 安全防護：
  - release + `MOCK_MODE=true` 會直接阻擋啟動。
  - 若要 QA，需額外設定 `ALLOW_MOCK_IN_RELEASE=true`。
- 已加入基礎單元測試：
  - 事件映射/分發
  - Session 持久化
  - API 錯誤映射
- iOS 實機驗收清單：`IOS_SMOKE_CHECKLIST.md`。

---

## 3. 學習路線圖

### 3.1 Flutter Widget 基礎

Flutter 的 UI 是由 Widget 樹組成的。你要先理解兩種 Widget 的差別：

| | `StatelessWidget` | `StatefulWidget` |
|-|-------------------|-----------------|
| 資料 | 不會變 | 會隨時間改變 |
| 用途 | 純展示 | 需要互動、API 呼叫 |
| 例子 | `AppAvatar`、`RoomStatusBadge` | `MapPage`、`FriendsPage` |

本專案的 Stateless Widget 範例（`lib/shared/widgets/avatar.dart`）：

```dart
class AppAvatar extends StatelessWidget {
  final String initials;  // 外部傳入，不會自己改變
  final double size;

  const AppAvatar({super.key, required this.initials, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Text(initials),
    );
  }
}
```

**重點**：`const` constructor 能讓 Flutter 跳過不必要的重建，盡量加上。

---

### 3.2 StatefulWidget 生命週期

這是本專案最重要的模式。幾乎每個 Page 都是 StatefulWidget。

```dart
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<Friend> _friends = [];   // 狀態變數：以底線開頭代表 private
  bool _loading = false;

  @override
  void initState() {
    super.initState();  // ← 一定要呼叫 super，而且要放第一行
    _load();            // ← 在這裡發 API，不要在 build()
  }

  @override
  void dispose() {
    // 清理資源：取消 StreamSubscription、Timer、Controller
    super.dispose();    // ← dispose 的 super 放最後一行
  }

  Future<void> _load() async {
    setState(() => _loading = true);  // 改變狀態 → 觸發 build()

    try {
      final data = await ApiClient.get('/api/v1/friends');
      if (!mounted) return;  // ← await 之後一定要檢查 mounted！
      setState(() {
        _friends = (data as List).map((j) => Friend.fromJson(j)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // build() 可能被呼叫很多次，只做「畫畫」，不要在這裡發 API
    return _loading
        ? const CircularProgressIndicator()
        : ListView(children: _friends.map((f) => Text(f.name)).toList());
  }
}
```

**最重要的規則**：  
`await` 之後、呼叫 `setState` 之前，永遠加 `if (!mounted) return;`  
否則 Widget 已經被銷毀了還去更新狀態，App 會 crash。

---

### 3.3 專案架構分層

```
lib/
├── core/           ← 基礎設施，全 App 共用
│   ├── design/     ← 顏色、字型、間距 (AppColors, AppTypography…)
│   ├── network/    ← HTTP + WebSocket client
│   ├── location/   ← GPS 服務
│   ├── router/     ← 路由設定
│   └── storage/    ← Session + Preferences
│
├── data/           ← 資料層
│   ├── models/     ← Dart 資料模型 (Room, Broadcast, Friend…)
│   └── services/   ← 跟 API 互動的 Service（BroadcastService）
│
├── features/       ← 功能模組
│   ├── auth/       ← 登入、Onboarding
│   ├── map/        ← 地圖（主功能）
│   ├── room/       ← 建立/查看房間
│   ├── friends/    ← 好友列表
│   └── profile/    ← 個人頁面
│
├── shared/         ← 跨功能共用的 Widget (AppAvatar, StatusBadge…)
└── mock/           ← 測試用假資料（不要在正式功能裡引用）
```

**跨功能規則**：`features/map/` 裡面的 Widget 不能直接 import `features/friends/` 的 Widget。  
跨功能只透過 **GoRouter** 導航，不直接引用對方的類別。

---

### 3.4 Service Singleton 模式

本專案的 Service 都是 **Singleton（單例）**，全 App 只有一個 instance。  
這讓不同的 Widget 可以共享同一個狀態（例如：地圖和個人頁都能看到 Broadcast 狀態）。

```dart
// lib/data/services/broadcast_service.dart

class BroadcastService {
  // ① 唯一的 instance
  static final BroadcastService instance = BroadcastService._();

  // ② private constructor，外部不能 new
  BroadcastService._();

  String? broadcastId;

  bool get isActive => broadcastId != null;  // ← 讀取狀態

  Future<void> start({required double lat, required double lng}) async {
    final result = await ApiClient.post('/api/v1/broadcasts', {
      'lat': lat, 'lng': lng,
    });
    broadcastId = result['id'] as String?;
  }

  Future<void> stop() async {
    final id = broadcastId;
    broadcastId = null;
    if (id != null) await ApiClient.delete('/api/v1/broadcasts/$id');
  }
}
```

使用方式：

```dart
// 在任何地方，直接用 .instance
await BroadcastService.instance.start(lat: 22.31, lng: 114.17);
final isOn = BroadcastService.instance.isActive;
```

同理，`Session.instance`、`WsClient.instance`、`LocationService.instance` 都是這個模式。

---

### 3.5 API Client 模式

所有 HTTP 呼叫都走 `ApiClient`（`lib/core/network/api_client.dart`）。  
它會自動帶上 `X-User-ID` header，你不需要每次手動加。

```dart
// GET（帶 query params）
final list = await ApiClient.get(
  '/api/v1/broadcasts/nearby',
  params: {'lat': '22.31', 'lng': '114.17', 'radius': '5000'},
);

// POST（帶 body）
final result = await ApiClient.post('/api/v1/rooms', {
  'lat': 22.31,
  'lng': 114.17,
});
final roomId = result['id'] as String;

// DELETE
await ApiClient.delete('/api/v1/broadcasts/$id');

// PATCH
await ApiClient.patch('/api/v1/broadcasts/$id/location', {
  'lat': newLat, 'lng': newLng,
});
```

**錯誤處理**：API 失敗時會 throw `ApiException`，裡面有 `statusCode` 和 `body`。

```dart
try {
  await ApiClient.post('/api/v1/rooms', body);
} on ApiException catch (e) {
  if (e.statusCode == 409) {
    // 例如：房間已滿
  }
} catch (e) {
  // 網路斷線等其他錯誤
}
```

---

### 3.6 WebSocket 即時更新

地圖頁用 WebSocket 接收即時事件（玩家上線/下線、房間更新）。  
`WsClient` 封裝了連線、斷線重連（exponential backoff）、事件 Stream。

**Server 推送的事件類型**：

| `type` 欄位 | 意義 |
|-------------|------|
| `broadcast_started` | 有新玩家開始廣播 |
| `broadcast_stopped` | 玩家停止廣播 |
| `broadcast_location_updated` | 玩家位置更新 |
| `room_created` | 新房間出現 |
| `room_updated` | 房間人數變動 |
| `room_dissolved` | 房間關閉 |

訂閱事件的模式：

```dart
// 在 StatefulWidget 的 State 裡
StreamSubscription<WsMessage>? _wsSub;

@override
void initState() {
  super.initState();
  _wsSub = WsClient.instance.stream.listen(_handleWsMessage);
}

@override
void dispose() {
  _wsSub?.cancel();  // ← 一定要取消！否則會 memory leak
  super.dispose();
}

void _handleWsMessage(WsMessage msg) {
  if (!mounted) return;
  switch (msg.type) {
    case 'broadcast_started':
      final b = Broadcast.fromJson(msg.data);
      setState(() => _players = [..._players, b]);

    case 'broadcast_stopped':
      final id = msg.data['id'] as String?;
      setState(() => _players = _players.where((p) => p.id != id).toList());

    case 'room_updated':
      final r = Room.fromJson(msg.data);
      setState(() {
        _rooms = [
          ..._rooms.where((x) => x.id != r.id),  // 移除舊的
          r,                                        // 加入新的
        ];
      });
  }
}
```

**重要**：WebSocket 連線在 `main()` 登入恢復時就建立，不要在單一頁面連線/斷線。  
頁面只需要 `listen` stream，不要呼叫 `connect()`。

---

### 3.7 GoRouter 導航

路由定義在 `lib/core/router/router.dart`。

**所有路由路徑**：

```
/onboarding     ← 第一次開啟 App
/login          ← 登入/註冊
/               ← 主頁（地圖 + 底部 TabBar）
/room/:id       ← 房間詳情
```

**在 Widget 裡導航**：

```dart
import 'package:go_router/go_router.dart';
import '../../../core/router/router.dart';  // 取得 AppRoutes 常數

// 跳轉（替換 stack）— 登入後進主頁用這個
context.go(AppRoutes.map);

// Push（疊加 stack）— 從主頁進房間詳情用這個
context.push(AppRoutes.room(roomId));

// 返回上一頁
context.pop();
```

**Auth Guard（自動重導向）**：  
`AppRouter` 裡有 `redirect` callback，會自動判斷：
- 已登入 → 嘗試去 `/onboarding` 或 `/login` → 自動跳到 `/`
- 未登入 → 嘗試去 `/` 或 `/room/:id` → 自動跳到 `/onboarding`

你新增的頁面，如果需要登入才能進入，只要在 `redirect` 裡把它的路徑加進去就好。

---

### 3.8 flutter_map 地圖

地圖核心是 `FlutterMap` Widget，由多個 Layer 疊加組成（由下到上）：

```dart
FlutterMap(
  mapController: _mapController,
  options: MapOptions(
    initialCenter: LatLng(22.3193, 114.1694),
    initialZoom: 14.5,
  ),
  children: [
    // Layer 1（最底層）：OSM 地圖底圖
    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),

    // Layer 2：廣播範圍圓圈
    CircleLayer(circles: [
      CircleMarker(
        point: _myLocation,
        radius: 5000,          // 單位：公尺
        useRadiusInMeter: true,
        color: Colors.blue.withOpacity(0.1),
      ),
    ]),

    // Layer 3：房間 Marker
    MarkerLayer(
      markers: _rooms.map((r) => Marker(
        point: r.position,
        width: 56, height: 56,
        child: GestureDetector(
          onTap: () => _selectRoom(r),
          child: RoomMapMarker(room: r),
        ),
      )).toList(),
    ),

    // Layer 4（最上層）：我的位置點
    MarkerLayer(markers: [
      Marker(point: _myLocation, width: 24, height: 24, child: _MyDot()),
    ]),
  ],
)
```

**用程式控制地圖**：

```dart
final _mapController = MapController();

// 移動到某個位置並設定縮放
_mapController.move(LatLng(22.32, 114.17), 15.0);
```

**座標系統**：後端和 flutter_map 都用 `{ lat, lng }` 格式，geolocator 給的是 `latitude/longitude`（意思一樣，只是欄位名不同）。

---

### 3.9 Geolocator 定位

定位功能封裝在 `LocationService`（`lib/core/location/location_service.dart`）。  
**不要直接用 `Geolocator`**，統一走 `LocationService`，它會處理權限和 fallback。

```dart
// 取得目前位置（一次性）
final LatLng pos = await LocationService.instance.getCurrentPosition();

// 持續追蹤位置（回傳 Stream）
_locationSub = LocationService.instance.watchPosition().listen((pos) {
  setState(() => _myLocation = pos);
  // 同時更新後端的廣播位置
  BroadcastService.instance.updateLocation(pos.latitude, pos.longitude);
});
```

如果用戶拒絕定位權限，`LocationService` 會自動 fallback 到香港的預設座標 `LatLng(22.3193, 114.1694)`，App 不會 crash。

**平台設定**（已設好，但你要知道）：
- iOS：`Info.plist` 要有 `NSLocationWhenInUseUsageDescription`
- Android：`AndroidManifest.xml` 要有 `ACCESS_FINE_LOCATION`

---

### 3.10 設計系統（Design System）

所有顏色、字型、間距都定義在 `lib/core/design/tokens.dart`。  
**絕對不要在 Widget 裡直接寫 magic number 或 hex color**。

```dart
// ❌ 不要這樣
color: Color(0xFFE85C26)
fontSize: 16

// ✅ 要這樣
color: AppColors.primary        // 麻將紅
style: AppTypography.bodyLarge  // 統一的字體樣式
padding: EdgeInsets.all(AppSpacing.md)  // 統一的間距
borderRadius: AppRadius.lg      // 統一的圓角
```

完整的 token 列表：

```dart
// 顏色
AppColors.primary        // #E85C26 麻將紅（主色）
AppColors.secondary      // #2B5EAB 藍色（好友、次要操作）
AppColors.background     // #F5F5F0 米紙白
AppColors.online         // 綠色（在線）
AppColors.waiting        // 黃色（等待中）
AppColors.full           // 紅色（已滿/危險操作）
AppColors.textSecondary  // 灰色次要文字

// 間距（spacing scale）
AppSpacing.xs = 4   sm = 8   md = 16   lg = 24   xl = 32   xxl = 48

// 字體（typography scale）
AppTypography.displayLarge    // 頁面大標題 32px/Bold
AppTypography.headlineMedium  // 卡片標題   17px/SemiBold
AppTypography.bodyMedium      // 正文       14px/Regular
AppTypography.labelSmall      // 標籤/說明  12px/Medium

// 圓角
AppRadius.sm / md / lg / xl / full
```

---

## 4. 新增一個功能的完整流程

以「新增封鎖用戶功能」為例，示範從 API 到 UI 的完整流程：

### Step 1：確認 API Endpoint

後端已有 `POST /api/v1/users/:id/block` 和 `DELETE /api/v1/users/:id/block`。  
（API 定義在後端 `router/router.go`）

### Step 2：新增 Model（如果需要）

如果 API 回傳新的資料結構，在 `lib/data/models/` 新增對應 Model。  
這個功能只是操作（無回傳資料），所以不需要新 Model。

### Step 3：在 UI 發 API 呼叫

以在 `FriendsPage` 的好友 tile 上長按封鎖為例：

```dart
Future<void> _blockUser(String userId) async {
  // ① 先問確認
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Block User'),
      content: const Text('This user will not be able to see you.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Block', style: TextStyle(color: AppColors.full)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  // ② 發 API
  try {
    await ApiClient.post('/api/v1/users/$userId/block', {});
    // ③ 更新 UI（從好友列表移除）
    setState(() => _friends.removeWhere((f) => f.userId == userId));
  } catch (e) {
    _snack('Failed to block user: $e');
  }
}
```

### Step 4：新增路由（如果需要新頁面）

如果你的功能需要一個新頁面（例如「封鎖列表頁」）：

```dart
// ① 在 lib/features/profile/pages/ 新增 blocked_users_page.dart

// ② 在 router.dart 新增路由
GoRoute(
  path: '/blocked-users',
  pageBuilder: (ctx, state) => const MaterialPage(
    child: BlockedUsersPage(),
  ),
),

// ③ 在 AppRoutes 加上路徑常數
static const blockedUsers = '/blocked-users';

// ④ 在需要的地方導航
context.push(AppRoutes.blockedUsers);
```

### Step 5：處理 WebSocket 事件（如果需要即時更新）

如果封鎖用戶後，地圖上要立刻消失他：

```dart
// 在 map_page.dart 的 _handleWsMessage 加一個 case
case 'user_blocked':
  final blockedId = msg.data['blocked_user_id'] as String?;
  if (blockedId != null) {
    setState(() {
      _players = _players.where((p) => p.userId != blockedId).toList();
    });
  }
```

### 新增功能 Checklist

- [ ] API endpoint 確認（問後端或看 router.go）
- [ ] 需要新 Model 嗎？→ 加在 `lib/data/models/`
- [ ] 需要新 Service 嗎？→ 加在 `lib/data/services/`
- [ ] 需要新頁面嗎？→ 加在 `lib/features/<功能>/pages/`，並在 router.dart 登記
- [ ] 需要新 Widget 嗎？→ 跨功能共用放 `lib/shared/widgets/`，單一功能用放功能目錄
- [ ] 所有 `await` 後有 `if (!mounted) return;`？
- [ ] 顏色/字型有用 `AppColors` / `AppTypography`？
- [ ] `StreamSubscription` 有在 `dispose()` 取消？
- [ ] `TextEditingController` / `AnimationController` 有在 `dispose()` 清理？

---

## 5. 修 Bug 的思路

### 常見 Bug 類型與定位方式

**Bug 1：畫面沒有更新**

資料改了，但畫面沒變。

```dart
// ❌ 這樣不會觸發重建
_friends.add(newFriend);

// ✅ 要包在 setState 裡
setState(() => _friends.add(newFriend));
```

**Bug 2：setState() called after dispose()**

App 在 debug 模式下出現紅色錯誤，訊息包含 "setState() called after dispose()"。

```dart
// ❌ await 之後沒有 mounted 檢查
final data = await ApiClient.get('/api/v1/friends');
setState(() => _friends = ...); // ← 頁面可能已被關閉！

// ✅ 加上 mounted 檢查
final data = await ApiClient.get('/api/v1/friends');
if (!mounted) return;
setState(() => _friends = ...);
```

**Bug 3：地圖 Marker 不出現**

先確認資料是否正確：
1. 在 `_loadNearby()` 裡加 `print(_players.length)` 確認資料有進來
2. 確認座標是否合理（後端回傳的 `lat`/`lng` 有沒有對換）
3. 確認 `if (_showPlayers)` 等顯示條件是否為 true

**Bug 4：WebSocket 收不到事件**

1. 確認 `WsClient.instance.connect(userId)` 有被呼叫（在 `main.dart` 或登入後）
2. 確認 `_wsSub = WsClient.instance.stream.listen(...)` 有在 `initState` 設定
3. 用 `print` 在 `_handleWsMessage` 開頭確認事件有沒有進來
4. 確認 server 推送的 `type` 欄位名稱跟你的 `case` 完全一致（大小寫敏感）

**Bug 5：API 永遠 401 / 403**

確認 `Session.instance.userId` 有值：
```dart
print('userId: ${Session.instance.userId}');
```
`ApiClient` 用 `X-User-ID` header 傳身份。如果 userId 是 null，header 就不會被帶上。

**Bug 6：導航後畫面是空白或顯示舊資料**

GoRouter 的 push 不會觸發目標頁面的 `initState` 第二次（因為 Widget 可能被 cache 了）。  
如果你需要每次進入頁面都重新抓資料，用 `go()` 取代 `push()`，或在 `didChangeDependencies()` 抓資料。

---

## 6. 常見陷阱與注意事項

### ⚠️ `mock_data.dart` 只能用來開發測試

`lib/mock/mock_data.dart` 裡有假資料，方便在還沒有後端時測試 UI。  
**正式功能一律不能 import mock data**，`PlayerStatus`/`RoomStatus` 這兩個 enum 已經移到 `lib/data/models/models.dart`。

### ⚠️ Session 是 async 的

`Session.instance.clear()` 現在是 `Future`，要加 `await`：

```dart
// ❌ 會在清完之前就繼續執行
Session.instance.clear();
context.go(AppRoutes.onboarding);

// ✅ 等清完再導航
await Session.instance.clear();
if (context.mounted) context.go(AppRoutes.onboarding);
```

### ⚠️ Broadcast 狀態以 `BroadcastService` 為準

不要自己另外存 `broadcastId`，統一用：

```dart
BroadcastService.instance.isActive   // 是否正在廣播
BroadcastService.instance.broadcastId // 廣播 ID
```

### ⚠️ `dispose()` 裡的清理順序

```dart
@override
void dispose() {
  _wsSub?.cancel();        // StreamSubscription
  _locationSub?.cancel();  // 另一個 StreamSubscription
  _tab.dispose();          // TabController
  _searchCtrl.dispose();   // TextEditingController
  super.dispose();         // ← super 永遠放最後
}
```

### ⚠️ 路由要用 `AppRoutes` 常數，不要寫死字串

```dart
// ❌ 字串打錯不會有 compile error
context.go('/rooom/123');

// ✅ 用常數，IDE 有自動補全
context.push(AppRoutes.room(roomId));
```

### ⚠️ 加新頁面後 redirect 邏輯要確認

`router.dart` 裡的 `redirect` 目前只放行 `/onboarding` 和 `/login` 給未登入用戶。  
如果你加了一個公開頁面（不需要登入就能看），記得把它的路徑加入例外：

```dart
redirect: (context, state) {
  final loggedIn = Session.instance.isLoggedIn;
  final loc = state.matchedLocation;
  final publicRoutes = [AppRoutes.onboarding, AppRoutes.login, '/your-new-public-page'];

  if (!loggedIn && !publicRoutes.contains(loc)) {
    return AppRoutes.onboarding;
  }
  return null;
},
```

---

## 快速上手指令

```bash
# 安裝依賴
flutter pub get

# 執行 App（需要模擬器或實機）
flutter run

# 只跑 iOS
flutter run -d ios

# 程式碼檢查（應該要 0 errors）
flutter analyze

# 跑測試
flutter test
```

後端服務跑在 `http://localhost:8080`，  
確認後端起來後再跑 App，否則所有 API 會失敗（App 不會 crash，會顯示 error banner）。
