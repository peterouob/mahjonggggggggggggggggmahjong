enum AppEventType {
  broadcastStarted,
  broadcastUpdated,
  broadcastStopped,
  roomCreated,
  roomPlayerJoined,
  roomPlayerLeft,
  roomFull,
  roomDissolved,
  friendRequest,
  friendAccepted,
  pong,
  unknown,
}

class AppEvent {
  final AppEventType type;
  final Map<String, dynamic> data;

  const AppEvent({required this.type, required this.data});

  static AppEvent fromTypeData(String rawType, Map<String, dynamic> data) {
    final type = switch (rawType) {
      'broadcast.started' => AppEventType.broadcastStarted,
      'broadcast.updated' => AppEventType.broadcastUpdated,
      'broadcast.stopped' => AppEventType.broadcastStopped,
      'room.created' => AppEventType.roomCreated,
      'room.player_joined' => AppEventType.roomPlayerJoined,
      'room.player_left' => AppEventType.roomPlayerLeft,
      'room.full' => AppEventType.roomFull,
      'room.dissolved' => AppEventType.roomDissolved,
      'friend.request' => AppEventType.friendRequest,
      'friend.accepted' => AppEventType.friendAccepted,
      'pong' => AppEventType.pong,
      _ => AppEventType.unknown,
    };
    return AppEvent(type: type, data: data);
  }
}
