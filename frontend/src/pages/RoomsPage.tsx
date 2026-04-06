import { useState, useEffect } from 'react'
import {
  Users, MapPin, Plus, X, Crown, LogIn, LogOut, Trash2, ChevronRight, RefreshCw,
} from 'lucide-react'
import { api } from '../api'
import type { Room, User, GeoPos, RoomSeat } from '../types'

const GAME_RULE_LABEL: Record<string, string> = {
  TAIWAN_MAHJONG: '台灣麻將',
  THREE_PLAYER: '三人麻將',
  NATIONAL_STANDARD: '國標麻將',
}

const STATUS_CFG: Record<string, { label: string; cls: string }> = {
  WAITING: { label: '等待中', cls: 'text-[#10B981] bg-[#10B981]/10 border-[#10B981]/25' },
  FULL:    { label: '已滿員', cls: 'text-[#F59E0B] bg-[#F59E0B]/10 border-[#F59E0B]/25' },
  PLAYING: { label: '遊戲中', cls: 'text-[#A78BFA] bg-[#7C3AED]/10 border-[#7C3AED]/25' },
  CLOSED:  { label: '已關閉', cls: 'text-[#475569] bg-[#475569]/10 border-[#475569]/25' },
}

interface Props {
  user: User
  pos: GeoPos | null
  onToast: (msg: string, type?: 'info' | 'success' | 'error' | 'warning') => void
  wsEvent: { type: string; data?: any } | null
}

function StatusBadge({ status }: { status: string }) {
  const c = STATUS_CFG[status] ?? STATUS_CFG.WAITING
  return (
    <span className={`text-xs px-2 py-0.5 rounded-full border font-semibold ${c.cls}`}>
      {c.label}
    </span>
  )
}

function activeSeats(seats: RoomSeat[] = []) {
  return seats.filter((s) => !s.leftAt)
}

function SeatGrid({ seats, max, size = 'sm' }: { seats: RoomSeat[]; max: number; size?: 'sm' | 'md' }) {
  const active = activeSeats(seats)
  return (
    <div className="flex gap-2">
      {Array.from({ length: max }, (_, i) => {
        const seat = active.find((s) => s.seatNum === i + 1) ?? active[i]
        const filled = !!seat
        const h = size === 'md' ? 'h-10' : 'h-8'
        return (
          <div
            key={i}
            className={`flex-1 ${h} rounded-lg flex items-center justify-center text-xs font-bold transition-colors ${
              filled
                ? 'bg-[#7C3AED]/25 text-[#A78BFA] border border-[#7C3AED]/35'
                : 'bg-[#252545] text-[#475569] border border-[#2A2A4A]'
            }`}
          >
            {filled ? seat.player?.displayName?.slice(0, 2) ?? '?' : i + 1}
          </div>
        )
      })}
    </div>
  )
}

export default function RoomsPage({ user, pos, onToast, wsEvent }: Props) {
  const [rooms, setRooms] = useState<Room[]>([])
  const [myRoom, setMyRoom] = useState<Room | null>(null)
  const [loading, setLoading] = useState(false)
  const [selectedRoom, setSelectedRoom] = useState<Room | null>(null)
  const [showCreate, setShowCreate] = useState(false)

  async function loadData() {
    setLoading(true)
    try {
      const [n, m] = await Promise.all([
        api.getNearbyRooms().catch(() => ({ rooms: [] })),
        api.getMyRoom().catch(() => ({ room: null })),
      ])
      setRooms(n.rooms ?? [])
      setMyRoom(m.room)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { loadData() }, [])

  useEffect(() => {
    if (!wsEvent?.data) return
    const { type, data } = wsEvent
    if (type === 'room.player_joined' || type === 'room.player_left' || type === 'room.full') {
      if (data.room) {
        setRooms((p) => p.map((r) => (r.id === data.roomId ? data.room : r)))
        if (myRoom?.id === data.roomId) setMyRoom(data.room)
        if (selectedRoom?.id === data.roomId) setSelectedRoom(data.room)
      }
      if (type === 'room.full') onToast('房間已滿員！', 'warning')
    } else if (type === 'room.dissolved') {
      setRooms((p) => p.filter((r) => r.id !== data.roomId))
      if (myRoom?.id === data.roomId) { setMyRoom(null); onToast('你所在的房間已解散', 'info') }
      if (selectedRoom?.id === data.roomId) setSelectedRoom(null)
    }
  }, [wsEvent])

  async function joinRoom(id: string) {
    try {
      const { room } = await api.joinRoom(id)
      setMyRoom(room)
      setRooms((p) => p.map((r) => (r.id === id ? room : r)))
      setSelectedRoom(room)
      onToast('成功加入房間！', 'success')
    } catch (err: any) { onToast(err.message, 'error') }
  }

  async function leaveRoom() {
    if (!myRoom) return
    try {
      await api.leaveRoom(myRoom.id)
      setMyRoom(null)
      setSelectedRoom(null)
      onToast('已離開房間', 'info')
      loadData()
    } catch (err: any) { onToast(err.message, 'error') }
  }

  async function dissolveRoom() {
    if (!myRoom) return
    try {
      await api.dissolveRoom(myRoom.id)
      setMyRoom(null)
      setSelectedRoom(null)
      onToast('房間已解散', 'info')
      loadData()
    } catch (err: any) { onToast(err.message, 'error') }
  }

  return (
    <div className="flex-1 overflow-y-auto px-4 py-4 pb-6 space-y-4">

      {/* My Room Banner */}
      {myRoom && (
        <div className={`rounded-2xl border p-4 transition-all duration-300 ${
          myRoom.status === 'FULL'
            ? 'bg-[#1E1A10] border-[#F59E0B] shadow-lg shadow-amber-900/20'
            : 'bg-[#1E1435] border-[#7C3AED] shadow-lg shadow-purple-900/25'
        }`}>
          <div className="flex items-start justify-between mb-2">
            <div>
              <p className="text-xs text-[#475569] mb-0.5">你目前所在的房間</p>
              <h3 className="font-bold text-[#E2E8F0] flex items-center gap-2">
                {myRoom.hostId === user.id && <Crown size={14} className="text-[#F59E0B]" />}
                {myRoom.name}
              </h3>
              <p className="text-xs text-[#94A3B8] mt-0.5">
                {GAME_RULE_LABEL[myRoom.gameRule]}{myRoom.placeName ? ` · ${myRoom.placeName}` : ''}
              </p>
            </div>
            <StatusBadge status={myRoom.status} />
          </div>
          <div className="my-3">
            <SeatGrid seats={myRoom.seats ?? []} max={myRoom.maxPlayers} size="md" />
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setSelectedRoom(myRoom)}
              className="flex-1 bg-[#252545] hover:bg-[#2A2A4A] text-[#94A3B8] py-2 rounded-xl text-sm cursor-pointer transition-colors flex items-center justify-center gap-1.5"
            >
              <ChevronRight size={14} /> 詳細
            </button>
            {myRoom.hostId === user.id ? (
              <button
                onClick={dissolveRoom}
                className="flex-1 bg-[#F43F5E]/10 hover:bg-[#F43F5E]/20 border border-[#F43F5E]/30 text-[#F43F5E] py-2 rounded-xl text-sm cursor-pointer transition-colors flex items-center justify-center gap-1.5"
              >
                <Trash2 size={14} /> 解散
              </button>
            ) : (
              <button
                onClick={leaveRoom}
                className="flex-1 bg-[#F43F5E]/10 hover:bg-[#F43F5E]/20 border border-[#F43F5E]/30 text-[#F43F5E] py-2 rounded-xl text-sm cursor-pointer transition-colors flex items-center justify-center gap-1.5"
              >
                <LogOut size={14} /> 離開
              </button>
            )}
          </div>
        </div>
      )}

      {/* Header */}
      <div className="flex items-center justify-between">
        <h2 className="font-semibold text-[#E2E8F0] flex items-center gap-2">
          附近房間
          {rooms.length > 0 && (
            <span className="text-xs bg-[#7C3AED]/20 text-[#A78BFA] px-2 py-0.5 rounded-full">
              {rooms.length}
            </span>
          )}
        </h2>
        <div className="flex items-center gap-2">
          <button
            onClick={loadData}
            disabled={loading}
            className="p-1 text-[#475569] hover:text-[#A78BFA] transition-colors cursor-pointer"
            aria-label="重新整理"
          >
            <RefreshCw size={15} className={loading ? 'animate-spin' : ''} />
          </button>
          {!myRoom && (
            <button
              onClick={() => setShowCreate(true)}
              disabled={!pos}
              className="flex items-center gap-1.5 bg-[#7C3AED] hover:bg-[#6D28D9] disabled:opacity-40 disabled:cursor-not-allowed text-white px-3 py-1.5 rounded-xl text-sm font-semibold cursor-pointer transition-colors"
            >
              <Plus size={15} /> 建立
            </button>
          )}
        </div>
      </div>

      {/* Empty */}
      {rooms.length === 0 && !loading ? (
        <div className="text-center py-16">
          <div className="w-16 h-16 rounded-2xl bg-[#1A1A3A] border border-[#2A2A4A] flex items-center justify-center mx-auto mb-4">
            <Users size={28} className="text-[#2A2A4A]" />
          </div>
          <p className="text-[#475569] text-sm">附近沒有開放的房間</p>
          <p className="text-[#2A2A4A] text-xs mt-1">建立一個房間開始遊戲！</p>
        </div>
      ) : (
        <div className="space-y-3">
          {rooms.map((r) => (
            <RoomCard
              key={r.id}
              room={r}
              userId={user.id}
              myRoomId={myRoom?.id}
              onJoin={joinRoom}
              onDetail={() => setSelectedRoom(r)}
            />
          ))}
        </div>
      )}

      {/* Room Detail Modal */}
      {selectedRoom && (
        <RoomDetailModal
          room={selectedRoom}
          userId={user.id}
          myRoomId={myRoom?.id}
          onJoin={joinRoom}
          onLeave={leaveRoom}
          onDissolve={dissolveRoom}
          onClose={() => setSelectedRoom(null)}
        />
      )}

      {/* Create Room Modal */}
      {showCreate && (
        <CreateRoomModal
          pos={pos}
          onClose={() => setShowCreate(false)}
          onCreated={(room) => {
            setMyRoom(room)
            setRooms((p) => [room, ...p])
            setShowCreate(false)
            onToast('房間建立成功！', 'success')
          }}
          onToast={onToast}
        />
      )}
    </div>
  )
}

// ─── Room Card ────────────────────────────────────────────────────────────────

function RoomCard({
  room, userId, myRoomId, onJoin, onDetail,
}: {
  room: Room; userId: string; myRoomId?: string
  onJoin: (id: string) => void; onDetail: () => void
}) {
  const filled = activeSeats(room.seats ?? []).length
  const isHere = myRoomId === room.id
  const canJoin = !myRoomId && room.status === 'WAITING' && filled < room.maxPlayers

  return (
    <div
      className="bg-[#1A1A3A] border border-[#2A2A4A] rounded-xl p-4 hover:border-[#7C3AED]/40 transition-colors cursor-pointer"
      onClick={onDetail}
    >
      <div className="flex items-start justify-between mb-2.5">
        <div>
          <div className="flex items-center gap-1.5">
            <span className="font-semibold text-[#E2E8F0]">{room.name}</span>
            {room.hostId === userId && <Crown size={13} className="text-[#F59E0B]" />}
          </div>
          <p className="text-xs text-[#94A3B8] mt-0.5">
            {GAME_RULE_LABEL[room.gameRule]}{room.placeName ? ` · ${room.placeName}` : ''}
          </p>
        </div>
        <StatusBadge status={room.status} />
      </div>

      <SeatGrid seats={room.seats ?? []} max={room.maxPlayers} />

      <div className="flex items-center justify-between mt-3">
        <span className="text-xs text-[#475569] flex items-center gap-1">
          <Users size={12} /> {filled}/{room.maxPlayers}
        </span>
        {isHere ? (
          <span className="text-xs text-[#A78BFA]">你在這裡</span>
        ) : canJoin ? (
          <button
            onClick={(e) => { e.stopPropagation(); onJoin(room.id) }}
            className="bg-[#7C3AED] hover:bg-[#6D28D9] text-white text-xs px-3 py-1.5 rounded-lg cursor-pointer transition-colors flex items-center gap-1"
          >
            <LogIn size={12} /> 加入
          </button>
        ) : null}
      </div>
    </div>
  )
}

// ─── Room Detail Modal ────────────────────────────────────────────────────────

function RoomDetailModal({
  room, userId, myRoomId, onJoin, onLeave, onDissolve, onClose,
}: {
  room: Room; userId: string; myRoomId?: string
  onJoin: (id: string) => void; onLeave: () => void
  onDissolve: () => void; onClose: () => void
}) {
  const active = activeSeats(room.seats ?? [])
  const isHere = myRoomId === room.id
  const isHost = room.hostId === userId
  const canJoin = !myRoomId && room.status === 'WAITING' && active.length < room.maxPlayers

  return (
    <div
      className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-end justify-center p-4"
      onClick={onClose}
    >
      <div
        className="bg-[#1A1A3A] rounded-2xl w-full max-w-sm border border-[#2A2A4A] shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="p-5">
          {/* Header */}
          <div className="flex items-start justify-between mb-4">
            <div>
              <h3 className="font-bold text-[#E2E8F0] text-lg flex items-center gap-2">
                {isHost && <Crown size={16} className="text-[#F59E0B]" />}
                {room.name}
              </h3>
              <p className="text-sm text-[#94A3B8]">{GAME_RULE_LABEL[room.gameRule]}</p>
              {room.placeName && (
                <p className="text-xs text-[#475569] flex items-center gap-1 mt-0.5">
                  <MapPin size={11} /> {room.placeName}
                </p>
              )}
            </div>
            <div className="flex items-center gap-2">
              <StatusBadge status={room.status} />
              <button onClick={onClose} className="text-[#475569] hover:text-[#94A3B8] cursor-pointer">
                <X size={18} />
              </button>
            </div>
          </div>

          {/* Seat grid */}
          <p className="text-xs text-[#475569] mb-2">
            玩家座位（{active.length}/{room.maxPlayers}）
          </p>
          <div className="grid grid-cols-2 gap-2 mb-5">
            {Array.from({ length: room.maxPlayers }, (_, i) => {
              const seat = active.find((s) => s.seatNum === i + 1) ?? active[i]
              return (
                <div
                  key={i}
                  className={`p-3 rounded-xl border flex items-center gap-2.5 ${
                    seat
                      ? 'bg-[#7C3AED]/10 border-[#7C3AED]/30'
                      : 'bg-[#252545] border-[#2A2A4A]'
                  }`}
                >
                  <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-xs font-bold ${
                    seat ? 'bg-[#7C3AED]/30 text-[#A78BFA]' : 'bg-[#1A1A3A] text-[#475569]'
                  }`}>
                    {seat ? seat.player?.displayName?.slice(0, 2) ?? '?' : i + 1}
                  </div>
                  <div>
                    <p className={`text-xs font-semibold ${seat ? 'text-[#E2E8F0]' : 'text-[#475569]'}`}>
                      {seat ? seat.player?.displayName ?? '玩家' : '空位'}
                    </p>
                    {seat?.playerId === room.hostId && (
                      <p className="text-xs text-[#F59E0B]">房主</p>
                    )}
                  </div>
                </div>
              )
            })}
          </div>

          {/* Action */}
          {!isHere && canJoin && (
            <button
              onClick={() => { onJoin(room.id); onClose() }}
              className="w-full bg-[#7C3AED] hover:bg-[#6D28D9] text-white py-3 rounded-xl font-semibold cursor-pointer transition-colors flex items-center justify-center gap-2"
            >
              <LogIn size={18} /> 加入房間
            </button>
          )}
          {isHere && !isHost && (
            <button
              onClick={() => { onLeave(); onClose() }}
              className="w-full bg-[#F43F5E]/10 hover:bg-[#F43F5E]/20 border border-[#F43F5E]/30 text-[#F43F5E] py-3 rounded-xl font-semibold cursor-pointer transition-colors flex items-center justify-center gap-2"
            >
              <LogOut size={18} /> 離開房間
            </button>
          )}
          {isHere && isHost && (
            <button
              onClick={() => { onDissolve(); onClose() }}
              className="w-full bg-[#F43F5E]/10 hover:bg-[#F43F5E]/20 border border-[#F43F5E]/30 text-[#F43F5E] py-3 rounded-xl font-semibold cursor-pointer transition-colors flex items-center justify-center gap-2"
            >
              <Trash2 size={18} /> 解散房間
            </button>
          )}
        </div>
      </div>
    </div>
  )
}

// ─── Create Room Modal ────────────────────────────────────────────────────────

function CreateRoomModal({
  pos, onClose, onCreated, onToast,
}: {
  pos: GeoPos | null
  onClose: () => void
  onCreated: (room: Room) => void
  onToast: (msg: string, type?: 'info' | 'success' | 'error') => void
}) {
  const [form, setForm] = useState({
    name: '',
    placeName: '',
    gameRule: 'TAIWAN_MAHJONG',
    isPublic: true,
  })
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!pos) { onToast('需要定位才能建立房間', 'error'); return }
    setLoading(true)
    try {
      const { room } = await api.createRoom({ ...form, latitude: pos.lat, longitude: pos.lng })
      onCreated(room)
    } catch (err: any) {
      onToast(err.message, 'error')
    } finally {
      setLoading(false)
    }
  }

  const inputCls = 'w-full bg-[#252545] border border-[#2A2A4A] rounded-xl px-4 py-2.5 text-sm text-[#E2E8F0] outline-none focus:border-[#7C3AED] transition-colors placeholder-[#475569]'

  return (
    <div
      className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-end justify-center p-4"
      onClick={onClose}
    >
      <div
        className="bg-[#1A1A3A] rounded-2xl p-6 w-full max-w-sm border border-[#2A2A4A] shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="font-bold text-[#E2E8F0] mb-5 flex items-center gap-2">
          <Plus size={18} className="text-[#7C3AED]" /> 建立新房間
        </h3>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs text-[#94A3B8] mb-1.5 font-semibold uppercase tracking-wide">
              房間名稱
            </label>
            <input
              value={form.name}
              onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))}
              maxLength={100}
              required
              className={inputCls}
              placeholder="例：週末歡樂麻將"
              autoFocus
            />
          </div>
          <div>
            <label className="block text-xs text-[#94A3B8] mb-1.5 font-semibold uppercase tracking-wide">
              地點（選填）
            </label>
            <input
              value={form.placeName}
              onChange={(e) => setForm((p) => ({ ...p, placeName: e.target.value }))}
              maxLength={100}
              className={inputCls}
              placeholder="例：大安區咖啡廳"
            />
          </div>
          <div>
            <label className="block text-xs text-[#94A3B8] mb-1.5 font-semibold uppercase tracking-wide">
              遊戲規則
            </label>
            <select
              value={form.gameRule}
              onChange={(e) => setForm((p) => ({ ...p, gameRule: e.target.value }))}
              className={`${inputCls} cursor-pointer`}
            >
              <option value="TAIWAN_MAHJONG">台灣麻將</option>
              <option value="THREE_PLAYER">三人麻將</option>
              <option value="NATIONAL_STANDARD">國標麻將</option>
            </select>
          </div>
          <div className="flex items-center justify-between py-1">
            <span className="text-sm text-[#94A3B8]">公開房間</span>
            <button
              type="button"
              onClick={() => setForm((p) => ({ ...p, isPublic: !p.isPublic }))}
              className={`relative inline-flex h-6 w-11 items-center rounded-full cursor-pointer transition-colors ${
                form.isPublic ? 'bg-[#7C3AED]' : 'bg-[#2A2A4A]'
              }`}
            >
              <span
                className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${
                  form.isPublic ? 'translate-x-6' : 'translate-x-1'
                }`}
              />
            </button>
          </div>
          <div className="flex gap-3 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 bg-[#252545] hover:bg-[#2A2A4A] text-[#94A3B8] py-3 rounded-xl text-sm cursor-pointer transition-colors"
            >
              取消
            </button>
            <button
              type="submit"
              disabled={loading || !form.name.trim()}
              className="flex-1 bg-[#7C3AED] hover:bg-[#6D28D9] disabled:opacity-50 text-white py-3 rounded-xl text-sm font-semibold cursor-pointer transition-colors"
            >
              {loading ? '建立中...' : '建立房間'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
