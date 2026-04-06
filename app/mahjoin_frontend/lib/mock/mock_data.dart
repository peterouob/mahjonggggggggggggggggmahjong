import 'package:latlong2/latlong.dart';

// ─── Mock mode flag ───────────────────────────────────────────────────────────
// Set to true to run the app with local mock data (no backend required).
const kMockMode =
  bool.fromEnvironment('MOCK_MODE', defaultValue: false);

// ─── Dev mock users (match backend MOCK_USERS=true) ─────────────────────────

class DevMockUser {
  final String id;
  final String displayName;
  final String username;
  const DevMockUser(
      {required this.id, required this.displayName, required this.username});
}

const devMockUsers = [
  DevMockUser(
      id: '66018674-ff04-4d50-b593-f89bc72f3bdb',
      displayName: 'Alice Wang',
      username: 'alice'),
  DevMockUser(
      id: 'a4c45f29-a48f-43e2-b3c5-0bb058d23a94',
      displayName: 'Bob Chen',
      username: 'bob'),
  DevMockUser(
      id: '68952f04-efd2-4658-8257-baa9937e9b43',
      displayName: 'Charlie Liu',
      username: 'charlie'),
  DevMockUser(
      id: '91e67fab-88c4-4dc7-ab88-5240a35d818d',
      displayName: 'Dave Lee',
      username: 'dave'),
  DevMockUser(
      id: '973d0af9-b582-4828-a3e0-26d2f801e55e',
      displayName: 'Eve Chen',
      username: 'eve'),
];

// ─── Models ─────────────────────────────────────────────────────────────────

enum PlayerStatus { online, playing, offline }
enum RoomStatus { waiting, full, playing }

class MockPlayer {
  final String id;
  final String name;
  final String avatar;
  final LatLng position;
  final PlayerStatus status;
  final bool isFriend;
  final int rating;
  final int gamesPlayed;
  final double distanceKm;

  const MockPlayer({
    required this.id,
    required this.name,
    required this.avatar,
    required this.position,
    required this.status,
    required this.isFriend,
    required this.rating,
    required this.gamesPlayed,
    required this.distanceKm,
  });
}

class MockRoom {
  final String id;
  final String hostName;
  final String hostAvatar;
  final LatLng position;
  final RoomStatus status;
  final int currentPlayers;
  final int maxPlayers;
  final String address;
  final double distanceKm;
  final List<String> playerAvatars;

  const MockRoom({
    required this.id,
    required this.hostName,
    required this.hostAvatar,
    required this.position,
    required this.status,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.address,
    required this.distanceKm,
    required this.playerAvatars,
  });
}

class MockUser {
  final String id;
  final String name;
  final String avatar;
  final int rating;
  final int gamesPlayed;
  final int wins;
  final int friends;

  const MockUser({
    required this.id,
    required this.name,
    required this.avatar,
    required this.rating,
    required this.gamesPlayed,
    required this.wins,
    required this.friends,
  });
}

// ─── Data ────────────────────────────────────────────────────────────────────

const myLocation = LatLng(22.3193, 114.1694); // Hong Kong

const mockCurrentUser = MockUser(
  id: 'me',
  name: 'Peter Chan',
  avatar: 'PC',
  rating: 1842,
  gamesPlayed: 128,
  wins: 71,
  friends: 12,
);

const mockNearbyPlayers = [
  MockPlayer(
    id: 'p1',
    name: 'Alice Wong',
    avatar: 'AW',
    position: LatLng(22.3220, 114.1720),
    status: PlayerStatus.online,
    isFriend: true,
    rating: 1920,
    gamesPlayed: 203,
    distanceKm: 0.4,
  ),
  MockPlayer(
    id: 'p2',
    name: 'Bob Lee',
    avatar: 'BL',
    position: LatLng(22.3175, 114.1710),
    status: PlayerStatus.online,
    isFriend: true,
    rating: 1750,
    gamesPlayed: 87,
    distanceKm: 0.6,
  ),
  MockPlayer(
    id: 'p3',
    name: 'David Cheung',
    avatar: 'DC',
    position: LatLng(22.3210, 114.1660),
    status: PlayerStatus.online,
    isFriend: false,
    rating: 1680,
    gamesPlayed: 55,
    distanceKm: 0.9,
  ),
  MockPlayer(
    id: 'p4',
    name: 'Emily Ho',
    avatar: 'EH',
    position: LatLng(22.3240, 114.1680),
    status: PlayerStatus.online,
    isFriend: false,
    rating: 1590,
    gamesPlayed: 42,
    distanceKm: 1.2,
  ),
  MockPlayer(
    id: 'p5',
    name: 'Frank Yip',
    avatar: 'FY',
    position: LatLng(22.3160, 114.1740),
    status: PlayerStatus.playing,
    isFriend: true,
    rating: 2010,
    gamesPlayed: 312,
    distanceKm: 1.5,
  ),
  MockPlayer(
    id: 'p6',
    name: 'Grace Lam',
    avatar: 'GL',
    position: LatLng(22.3200, 114.1630),
    status: PlayerStatus.online,
    isFriend: false,
    rating: 1710,
    gamesPlayed: 91,
    distanceKm: 1.8,
  ),
];

const mockRooms = [
  MockRoom(
    id: 'r1',
    hostName: 'Alice Wong',
    hostAvatar: 'AW',
    position: LatLng(22.3220, 114.1720),
    status: RoomStatus.waiting,
    currentPlayers: 2,
    maxPlayers: 4,
    address: 'Mong Kok Community Centre',
    distanceKm: 0.4,
    playerAvatars: ['AW', 'BL'],
  ),
  MockRoom(
    id: 'r2',
    hostName: 'Frank Yip',
    hostAvatar: 'FY',
    position: LatLng(22.3160, 114.1740),
    status: RoomStatus.playing,
    currentPlayers: 4,
    maxPlayers: 4,
    address: 'Jordan Recreation Centre',
    distanceKm: 1.5,
    playerAvatars: ['FY', 'DC', 'EH', 'GL'],
  ),
  MockRoom(
    id: 'r3',
    hostName: 'Tom Ng',
    hostAvatar: 'TN',
    position: LatLng(22.3250, 114.1650),
    status: RoomStatus.waiting,
    currentPlayers: 3,
    maxPlayers: 4,
    address: 'Yau Ma Tei Club',
    distanceKm: 2.1,
    playerAvatars: ['TN', 'KW', 'SL'],
  ),
];

const mockFriends = [
  MockPlayer(
    id: 'p1',
    name: 'Alice Wong',
    avatar: 'AW',
    position: LatLng(22.3220, 114.1720),
    status: PlayerStatus.online,
    isFriend: true,
    rating: 1920,
    gamesPlayed: 203,
    distanceKm: 0.4,
  ),
  MockPlayer(
    id: 'p2',
    name: 'Bob Lee',
    avatar: 'BL',
    position: LatLng(22.3175, 114.1710),
    status: PlayerStatus.online,
    isFriend: true,
    rating: 1750,
    gamesPlayed: 87,
    distanceKm: 0.6,
  ),
  MockPlayer(
    id: 'p5',
    name: 'Frank Yip',
    avatar: 'FY',
    position: LatLng(22.3160, 114.1740),
    status: PlayerStatus.playing,
    isFriend: true,
    rating: 2010,
    gamesPlayed: 312,
    distanceKm: 1.5,
  ),
  MockPlayer(
    id: 'f4',
    name: 'Kenny Wu',
    avatar: 'KW',
    position: LatLng(22.3280, 114.1760),
    status: PlayerStatus.offline,
    isFriend: true,
    rating: 1630,
    gamesPlayed: 67,
    distanceKm: 3.2,
  ),
  MockPlayer(
    id: 'f5',
    name: 'Mandy Chan',
    avatar: 'MC',
    position: LatLng(22.3100, 114.1600),
    status: PlayerStatus.offline,
    isFriend: true,
    rating: 1580,
    gamesPlayed: 44,
    distanceKm: 4.8,
  ),
];
