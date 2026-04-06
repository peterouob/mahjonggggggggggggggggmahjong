import 'package:latlong2/latlong.dart';

enum PlayerStatus { online, playing, offline }

enum RoomStatus { waiting, full, playing }

String _initials(String name) {
  final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// Represents a nearby player who is actively broadcasting their location.
class Broadcast {
  final String id;
  final String userId;
  final String userName;
  final LatLng position;
  final double distanceKm;
  final int? rating;

  const Broadcast({
    required this.id,
    required this.userId,
    required this.userName,
    required this.position,
    required this.distanceKm,
    this.rating,
  });

  String get avatar => _initials(userName);
  PlayerStatus get status => PlayerStatus.online;
  bool get isFriend => false;

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    // Support both nearby search (distanceMeters) and direct fetch.
    final distanceM = (json['distanceMeters'] as num?)?.toDouble() ?? 0;

    // Player info lives in the nested `player` object.
    final player = json['player'] as Map<String, dynamic>?;
    final playerId = json['playerId'] as String? ?? player?['id'] as String? ?? '';
    final displayName = player?['displayName'] as String? ??
        player?['username'] as String? ??
        json['displayName'] as String? ??
        'Unknown';

    return Broadcast(
      id: json['id'] as String,
      userId: playerId,
      userName: displayName,
      position: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      distanceKm: distanceM / 1000,
      rating: json['rating'] as int?,
    );
  }
}

class RoomMember {
  final String userId;
  final String userName;

  const RoomMember({required this.userId, required this.userName});

  String get avatar => _initials(userName);

  /// Build from a backend RoomSeat object (contains nested `player`).
  factory RoomMember.fromSeatJson(Map<String, dynamic> json) {
    final player = json['player'] as Map<String, dynamic>?;
    return RoomMember(
      userId: json['playerId'] as String? ?? player?['id'] as String? ?? '',
      userName: player?['displayName'] as String? ??
          player?['username'] as String? ??
          'Unknown',
    );
  }
}

/// Represents a nearby Mahjong room.
class Room {
  final String id;
  final String hostId;
  final String hostName;
  final LatLng position;
  final RoomStatus status;
  final int currentPlayers;
  final int maxPlayers;
  final String address;
  final double distanceKm;
  final List<RoomMember> members;

  const Room({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.position,
    required this.status,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.address,
    required this.distanceKm,
    required this.members,
  });

  String get hostAvatar => _initials(hostName);
  List<String> get playerAvatars => members.map((m) => m.avatar).toList();

  factory Room.fromJson(Map<String, dynamic> json) {
    // Backend returns uppercase status strings.
    final statusStr = (json['status'] as String? ?? '').toUpperCase();
    final status = switch (statusStr) {
      'PLAYING' => RoomStatus.playing,
      'FULL' => RoomStatus.full,
      _ => RoomStatus.waiting,
    };

    // Seats are the source of truth for members.
    final seatsJson = json['seats'] as List<dynamic>? ?? [];
    final members = seatsJson
        .where((s) => (s as Map<String, dynamic>)['leftAt'] == null)
        .map((s) => RoomMember.fromSeatJson(s as Map<String, dynamic>))
        .toList();

    // Host info from nested `host` object.
    final host = json['host'] as Map<String, dynamic>?;
    final hostName = host?['displayName'] as String? ??
        host?['username'] as String? ??
        'Unknown';

    return Room(
      id: json['id'] as String,
      hostId: json['hostId'] as String? ?? '',
      hostName: hostName,
      position: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      status: status,
      currentPlayers: members.length,
      maxPlayers: json['maxPlayers'] as int? ?? 4,
      address: json['placeName'] as String? ??
          json['name'] as String? ??
          'Room',
      distanceKm: ((json['distanceMeters'] as num?)?.toDouble() ?? 0) / 1000,
      members: members,
    );
  }
}
