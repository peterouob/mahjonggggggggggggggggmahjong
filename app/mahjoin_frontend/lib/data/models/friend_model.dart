import 'models.dart' show PlayerStatus;

String _initials(String name) {
  final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// Represents a friend from GET /api/v1/friends
class Friend {
  final String id; // friendship record ID
  final String userId;
  final String userName;
  final bool isOnline;
  final bool isPlaying;
  final double distanceKm;
  final int? rating;

  const Friend({
    required this.id,
    required this.userId,
    required this.userName,
    required this.isOnline,
    required this.isPlaying,
    required this.distanceKm,
    this.rating,
  });

  String get name => userName;
  String get avatar => _initials(userName);
  bool get isFriend => true;

  PlayerStatus get status {
    if (isPlaying) return PlayerStatus.playing;
    if (isOnline) return PlayerStatus.online;
    return PlayerStatus.offline;
  }

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      userName: json['username'] as String? ??
          json['user_name'] as String? ??
          'Unknown',
      isOnline: json['is_online'] as bool? ?? false,
      isPlaying: json['is_playing'] as bool? ?? false,
      distanceKm: ((json['distance_m'] as num?)?.toDouble() ?? 0) / 1000,
      rating: json['rating'] as int?,
    );
  }
}

/// Represents an incoming friend request from GET /api/v1/friends/requests
class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUserName;

  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
  });

  String get fromAvatar => _initials(fromUserName);

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      fromUserId: json['from_user_id'] as String? ?? '',
      fromUserName: json['from_username'] as String? ??
          json['from_user_name'] as String? ??
          'Unknown',
    );
  }
}
