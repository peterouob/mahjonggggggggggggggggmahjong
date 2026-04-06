import 'models.dart' show PlayerStatus;

String _initials(String name) {
  final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// Represents a friend from GET /api/v1/friends
/// Backend returns domain.User objects; id == user's UUID (used for remove).
class Friend {
  final String id; // friend's user ID — used in DELETE /friends/:id
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

  /// Backend returns domain.User: {id, username, displayName, avatarUrl, ...}
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      userId: json['id'] as String,
      userName: json['displayName'] as String? ??
          json['username'] as String? ??
          'Unknown',
      // Online/playing/distance not available in current backend response.
      isOnline: json['isOnline'] as bool? ?? false,
      isPlaying: json['isPlaying'] as bool? ?? false,
      distanceKm: ((json['distanceMeters'] as num?)?.toDouble() ?? 0) / 1000,
      rating: json['rating'] as int?,
    );
  }
}

/// Represents an incoming friend request from GET /api/v1/friends/requests
/// Backend returns the enriched pendingRequestView:
/// {id, fromUserId, fromUsername, fromDisplayName, createdAt}
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
      fromUserId: json['fromUserId'] as String? ?? '',
      fromUserName: json['fromDisplayName'] as String? ??
          json['fromUsername'] as String? ??
          'Unknown',
    );
  }
}
