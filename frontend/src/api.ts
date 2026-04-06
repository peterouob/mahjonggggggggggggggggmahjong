import type { User, Broadcast, Room, FriendRequest } from './types'
import { mockApi } from './mockApi'

export const MOCK_MODE = true

const API_BASE = 'http://localhost:8080/api/v1'
export const WS_URL = (userId: string) => `ws://localhost:8080/ws?user_id=${userId}`

function headers(): HeadersInit {
  const userId = localStorage.getItem('userId') || ''
  return {
    'Content-Type': 'application/json',
    ...(userId && { 'X-User-ID': userId }),
  }
}

async function req<T>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: headers(),
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })
  const data = await res.json()
  if (!res.ok) throw new Error(data.error?.message || 'Request failed')
  return data as T
}

const realApi = {
  register: (b: { username: string; email: string; password: string; displayName: string }) =>
    req<{ user: User }>('POST', '/auth/register', b),

  login: (b: { username: string; password: string }) =>
    req<{ user: User }>('POST', '/auth/login', b),

  startBroadcast: (b: { latitude: number; longitude: number; message?: string }) =>
    req<{ broadcast: Broadcast }>('POST', '/broadcasts', b),

  stopBroadcast: (id: string) =>
    req<{ message: string }>('DELETE', `/broadcasts/${id}`),

  heartbeat: (id: string) =>
    req<{ message: string }>('POST', `/broadcasts/${id}/heartbeat`),

  updateBroadcastLocation: (id: string, b: { latitude: number; longitude: number }) =>
    req<{ message: string }>('PATCH', `/broadcasts/${id}/location`, b),

  getNearbyBroadcasts: (lat: number, lng: number, radiusKm = 5) =>
    req<{ broadcasts: Broadcast[] }>('GET', `/broadcasts/nearby?lat=${lat}&lng=${lng}&radius_km=${radiusKm}`),

  getMyBroadcast: () =>
    req<{ broadcast: Broadcast | null }>('GET', '/broadcasts/me'),

  createRoom: (b: {
    name: string; placeName?: string; gameRule?: string
    isPublic?: boolean; latitude: number; longitude: number
  }) => req<{ room: Room }>('POST', '/rooms', b),

  getNearbyRooms: () =>
    req<{ rooms: Room[] }>('GET', '/rooms/nearby'),

  getMyRoom: () =>
    req<{ room: Room | null }>('GET', '/rooms/me'),

  getRoom: (id: string) =>
    req<{ room: Room }>('GET', `/rooms/${id}`),

  joinRoom: (id: string) =>
    req<{ room: Room }>('POST', `/rooms/${id}/join`),

  leaveRoom: (id: string) =>
    req<{ message: string }>('POST', `/rooms/${id}/leave`),

  dissolveRoom: (id: string) =>
    req<{ message: string }>('DELETE', `/rooms/${id}`),

  getFriends: () =>
    req<{ friends: User[] }>('GET', '/friends'),

  getFriendRequests: () =>
    req<{ requests: FriendRequest[] }>('GET', '/friends/requests'),

  sendFriendRequest: (toId: string) =>
    req<{ message: string }>('POST', '/friends/requests', { toId }),

  acceptFriendRequest: (id: string) =>
    req<{ message: string }>('PUT', `/friends/requests/${id}/accept`),

  rejectFriendRequest: (id: string) =>
    req<{ message: string }>('PUT', `/friends/requests/${id}/reject`),

  removeFriend: (id: string) =>
    req<{ message: string }>('DELETE', `/friends/${id}`),

  blockUser: (id: string) =>
    req<{ message: string }>('POST', `/users/${id}/block`),

  unblockUser: (id: string) =>
    req<{ message: string }>('DELETE', `/users/${id}/block`),
}

export const api = MOCK_MODE ? mockApi : realApi
