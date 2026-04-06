export interface User {
  id: string
  username: string
  email: string
  displayName: string
  avatarUrl: string
  createdAt: string
  updatedAt: string
}

export interface Broadcast {
  id: string
  playerId: string
  latitude: number
  longitude: number
  status: 'ACTIVE' | 'STOPPED'
  message: string
  expiresAt: string
  createdAt: string
  updatedAt: string
  player?: User
  distanceMeters?: number
}

export type GameRule = 'TAIWAN_MAHJONG' | 'THREE_PLAYER' | 'NATIONAL_STANDARD'
export type RoomStatus = 'WAITING' | 'FULL' | 'PLAYING' | 'CLOSED'

export interface RoomSeat {
  id: string
  roomId: string
  playerId: string
  seatNum: number
  joinedAt: string
  leftAt: string | null
  player?: User
}

export interface Room {
  id: string
  hostId: string
  name: string
  placeName: string
  gameRule: GameRule
  isPublic: boolean
  status: RoomStatus
  latitude: number
  longitude: number
  maxPlayers: number
  createdAt: string
  updatedAt: string
  seats?: RoomSeat[]
  host?: User
}

export interface FriendRequest {
  id: string
  userIdA: string
  userIdB: string
  status: 'PENDING' | 'ACCEPTED' | 'REJECTED'
  initiatorId: string
  fromUser?: User
  createdAt: string
  updatedAt: string
}

export type TabId = 'discover' | 'rooms' | 'friends' | 'profile'

export interface Toast {
  id: string
  message: string
  type: 'info' | 'success' | 'error' | 'warning'
}

export interface GeoPos {
  lat: number
  lng: number
}
