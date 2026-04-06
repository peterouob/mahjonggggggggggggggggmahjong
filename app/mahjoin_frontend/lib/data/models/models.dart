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
    return Broadcast(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      userName: json['username'] as String? ??
          json['user_name'] as String? ??
          'Unknown',
      position: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      distanceKm: ((json['distance_m'] as num?)?.toDouble() ?? 0) / 1000,
      rating: json['rating'] as int?,
    );
  }
}

class RoomMember {
  final String userId;
  final String userName;

  const RoomMember({required this.userId, required this.userName});

  String get avatar => _initials(userName);

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      userId: json['user_id'] as String? ?? '',
      userName: json['username'] as String? ??
          json['user_name'] as String? ??
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
    final statusStr = json['status'] as String? ?? 'waiting';
    final status = switch (statusStr) {
      'playing' => RoomStatus.playing,
      'full' => RoomStatus.full,
      _ => RoomStatus.waiting,
    };
    final membersJson = json['members'] as List<dynamic>? ?? [];
    final members = membersJson
        .map((m) => RoomMember.fromJson(m as Map<String, dynamic>))
        .toList();

    return Room(
      id: json['id'] as String,
      hostId: json['host_id'] as String? ?? '',
      hostName: json['host_name'] as String? ?? 'Unknown',
      position: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      status: status,
      currentPlayers: json['current_players'] as int? ?? members.length,
      maxPlayers: json['max_players'] as int? ?? 4,
      address: json['address'] as String? ?? 'Room',
      distanceKm: ((json['distance_m'] as num?)?.toDouble() ?? 0) / 1000,
      members: members,
    );
  }
}
