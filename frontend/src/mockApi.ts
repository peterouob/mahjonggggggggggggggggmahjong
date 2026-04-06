import type { User, Broadcast, Room, FriendRequest, RoomSeat } from './types'

// ── Helpers ───────────────────────────────────────────────────────────────────

function uid() {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36)
}
const now = () => new Date().toISOString()
const future = (mins: number) => new Date(Date.now() + mins * 60000).toISOString()
const ago = (mins: number) => new Date(Date.now() - mins * 60000).toISOString()

// ── Seed users ────────────────────────────────────────────────────────────────

const uAlice: User = {
  id: 'mock-u1', username: 'alice_w', email: 'alice@mock',
  displayName: 'Alice Wong', avatarUrl: '', createdAt: ago(120), updatedAt: now(),
}
const uBob: User = {
  id: 'mock-u2', username: 'bob_l', email: 'bob@mock',
  displayName: 'Bob Lee', avatarUrl: '', createdAt: ago(240), updatedAt: now(),
}
const uDave: User = {
  id: 'mock-u3', username: 'dave_c', email: 'dave@mock',
  displayName: 'Dave Chan', avatarUrl: '', createdAt: ago(300), updatedAt: now(),
}

// ── Seed broadcasts ───────────────────────────────────────────────────────────

const seedBroadcasts: Broadcast[] = [
  {
    id: 'b-alice', playerId: uAlice.id,
    latitude: 25.0428, longitude: 121.5348,
    status: 'ACTIVE', message: '找人打台灣麻將，歡迎新手！',
    expiresAt: future(10), createdAt: ago(3), updatedAt: now(),
    player: uAlice, distanceMeters: 430,
  },
  {
    id: 'b-bob', playerId: uBob.id,
    latitude: 25.0412, longitude: 121.5370,
    status: 'ACTIVE', message: '三缺一，手氣好的來',
    expiresAt: future(8), createdAt: ago(8), updatedAt: now(),
    player: uBob, distanceMeters: 870,
  },
  {
    id: 'b-dave', playerId: uDave.id,
    latitude: 25.0395, longitude: 121.5310,
    status: 'ACTIVE', message: '',
    expiresAt: future(5), createdAt: ago(14), updatedAt: now(),
    player: uDave, distanceMeters: 1350,
  },
]

// ── Seed rooms ────────────────────────────────────────────────────────────────

const seatAlice: RoomSeat = {
  id: 's1', roomId: 'room-1', playerId: uAlice.id,
  seatNum: 1, joinedAt: ago(15), leftAt: null, player: uAlice,
}
const seatBob: RoomSeat = {
  id: 's2', roomId: 'room-1', playerId: uBob.id,
  seatNum: 2, joinedAt: ago(14), leftAt: null, player: uBob,
}

const seedRooms: Room[] = [
  {
    id: 'room-1', hostId: uAlice.id, name: '週末歡樂麻將',
    placeName: '大安區咖啡廳', gameRule: 'TAIWAN_MAHJONG',
    isPublic: true, status: 'WAITING',
    latitude: 25.0428, longitude: 121.5348,
    maxPlayers: 4, createdAt: ago(20), updatedAt: now(),
    seats: [seatAlice, seatBob], host: uAlice,
  },
]

// ── Mutable in-memory state ───────────────────────────────────────────────────

let _myBroadcast: Broadcast | null = null
let _myRoom: Room | null = null
const _nearbyBroadcasts: Broadcast[] = [...seedBroadcasts]
const _nearbyRooms: Room[] = [...seedRooms]
const _friends: User[] = []
const _friendRequests: FriendRequest[] = []

// ── Mock implementations ──────────────────────────────────────────────────────

export const mockApi = {
  register: (_b: { username: string; email: string; password: string; displayName: string }): Promise<{ user: User }> =>
    Promise.reject(new Error('Not used in mock mode')),

  login: (_b: { username: string; password: string }): Promise<{ user: User }> =>
    Promise.reject(new Error('Not used in mock mode')),

  startBroadcast: (b: { latitude: number; longitude: number; message?: string }): Promise<{ broadcast: Broadcast }> => {
    _myBroadcast = {
      id: uid(), playerId: 'me',
      latitude: b.latitude, longitude: b.longitude,
      status: 'ACTIVE', message: b.message ?? '',
      expiresAt: future(10), createdAt: now(), updatedAt: now(),
    }
    return Promise.resolve({ broadcast: _myBroadcast })
  },

  stopBroadcast: (_id: string): Promise<{ message: string }> => {
    _myBroadcast = null
    return Promise.resolve({ message: 'stopped' })
  },

  heartbeat: (_id: string): Promise<{ message: string }> =>
    Promise.resolve({ message: 'ok' }),

  updateBroadcastLocation: (id: string, b: { latitude: number; longitude: number }): Promise<{ message: string }> => {
    if (_myBroadcast?.id === id) {
      _myBroadcast = { ..._myBroadcast, latitude: b.latitude, longitude: b.longitude, updatedAt: now() }
    }
    return Promise.resolve({ message: 'ok' })
  },

  getNearbyBroadcasts: (_lat: number, _lng: number, _r?: number): Promise<{ broadcasts: Broadcast[] }> =>
    Promise.resolve({ broadcasts: _nearbyBroadcasts.filter(b => b.status === 'ACTIVE') }),

  getMyBroadcast: (): Promise<{ broadcast: Broadcast | null }> =>
    Promise.resolve({ broadcast: _myBroadcast }),

  createRoom: (b: {
    name: string; placeName?: string; gameRule?: string
    isPublic?: boolean; latitude: number; longitude: number
  }): Promise<{ room: Room }> => {
    const room: Room = {
      id: uid(), hostId: 'me',
      name: b.name, placeName: b.placeName ?? '',
      gameRule: (b.gameRule ?? 'TAIWAN_MAHJONG') as Room['gameRule'],
      isPublic: b.isPublic ?? true, status: 'WAITING',
      latitude: b.latitude, longitude: b.longitude,
      maxPlayers: 4, createdAt: now(), updatedAt: now(),
      seats: [], host: undefined,
    }
    _myRoom = room
    _nearbyRooms.unshift(room)
    return Promise.resolve({ room })
  },

  getNearbyRooms: (): Promise<{ rooms: Room[] }> =>
    Promise.resolve({ rooms: _nearbyRooms }),

  getMyRoom: (): Promise<{ room: Room | null }> =>
    Promise.resolve({ room: _myRoom }),

  getRoom: (id: string): Promise<{ room: Room }> => {
    const room = _nearbyRooms.find(r => r.id === id) ?? _myRoom
    if (!room) return Promise.reject(new Error('Room not found'))
    return Promise.resolve({ room })
  },

  joinRoom: (id: string): Promise<{ room: Room }> => {
    const room = _nearbyRooms.find(r => r.id === id)
    if (!room) return Promise.reject(new Error('Room not found'))
    _myRoom = room
    return Promise.resolve({ room })
  },

  leaveRoom: (_id: string): Promise<{ message: string }> => {
    _myRoom = null
    return Promise.resolve({ message: 'left' })
  },

  dissolveRoom: (id: string): Promise<{ message: string }> => {
    const idx = _nearbyRooms.findIndex(r => r.id === id)
    if (idx >= 0) _nearbyRooms.splice(idx, 1)
    if (_myRoom?.id === id) _myRoom = null
    return Promise.resolve({ message: 'dissolved' })
  },

  getFriends: (): Promise<{ friends: User[] }> =>
    Promise.resolve({ friends: _friends }),

  getFriendRequests: (): Promise<{ requests: FriendRequest[] }> =>
    Promise.resolve({ requests: _friendRequests }),

  sendFriendRequest: (_toId: string): Promise<{ message: string }> =>
    Promise.resolve({ message: 'sent' }),

  acceptFriendRequest: (_id: string): Promise<{ message: string }> =>
    Promise.resolve({ message: 'accepted' }),

  rejectFriendRequest: (_id: string): Promise<{ message: string }> =>
    Promise.resolve({ message: 'rejected' }),

  removeFriend: (_id: string): Promise<{ message: string }> =>
    Promise.resolve({ message: 'removed' }),

  blockUser: (_id: string): Promise<{ message: string }> =>
    Promise.resolve({ message: 'blocked' }),

  unblockUser: (_id: string): Promise<{ message: string }> =>
    Promise.resolve({ message: 'unblocked' }),
}
