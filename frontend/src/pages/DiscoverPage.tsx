import { useState, useEffect, useRef } from 'react'
import { Radio, MapPin, Clock, RefreshCw, X, Send, WifiOff, UserPlus } from 'lucide-react'
import { api } from '../api'
import type { Broadcast, User, GeoPos } from '../types'

interface Props {
  user: User
  pos: GeoPos | null
  geoError: string | null
  onToast: (msg: string, type?: 'info' | 'success' | 'error' | 'warning') => void
  wsEvent: { type: string; data?: any } | null
}

function formatDist(m: number) {
  return m < 1000 ? `${Math.round(m)} m` : `${(m / 1000).toFixed(1)} km`
}

function timeAgo(s: string) {
  const m = Math.floor((Date.now() - new Date(s).getTime()) / 60000)
  if (m < 1) return '剛剛'
  if (m < 60) return `${m} 分鐘前`
  return `${Math.floor(m / 60)} 小時前`
}

export default function DiscoverPage({ user, pos, geoError, onToast, wsEvent }: Props) {
  const [myBroadcast, setMyBroadcast] = useState<Broadcast | null>(null)
  const [broadcasts, setBroadcasts] = useState<Broadcast[]>([])
  const [loading, setLoading] = useState(false)
  const [showModal, setShowModal] = useState(false)
  const [message, setMessage] = useState('')
  const [starting, setStarting] = useState(false)
  const heartbeatRef = useRef<ReturnType<typeof setInterval> | undefined>(undefined)

  async function loadData() {
    setLoading(true)
    try {
      const [mine, nearby] = await Promise.all([
        api.getMyBroadcast().catch(() => ({ broadcast: null })),
        pos
          ? api.getNearbyBroadcasts(pos.lat, pos.lng).catch(() => ({ broadcasts: [] }))
          : Promise.resolve({ broadcasts: [] }),
      ])
      setMyBroadcast(mine.broadcast)
      setBroadcasts((nearby.broadcasts ?? []).filter((b) => b.playerId !== user.id))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { loadData() }, [pos?.lat, pos?.lng])

  useEffect(() => {
    const id = setInterval(loadData, 30000)
    return () => clearInterval(id)
  }, [pos?.lat, pos?.lng])

  // Auto heartbeat every 5 min
  useEffect(() => {
    if (!myBroadcast) return
    heartbeatRef.current = setInterval(async () => {
      try { await api.heartbeat(myBroadcast.id) } catch {}
    }, 5 * 60 * 1000)
    return () => clearInterval(heartbeatRef.current)
  }, [myBroadcast?.id])

  // Real-time WS events
  useEffect(() => {
    if (!wsEvent) return
    const { type, data } = wsEvent
    if (!data) return
    if (type === 'broadcast.started' && data.playerId !== user.id) {
      setBroadcasts((prev) => {
        if (prev.find((b) => b.id === data.broadcastId)) return prev
        return [
          {
            id: data.broadcastId,
            playerId: data.playerId,
            latitude: data.latitude,
            longitude: data.longitude,
            message: data.message,
            status: 'ACTIVE' as const,
            distanceMeters: data.distanceMeters,
            expiresAt: '',
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            player: {
              id: data.playerId,
              displayName: data.displayName,
              avatarUrl: data.avatarUrl,
              username: '',
              email: '',
              createdAt: '',
              updatedAt: '',
            },
          },
          ...prev,
        ]
      })
    } else if (type === 'broadcast.updated') {
      setBroadcasts((prev) =>
        prev.map((b) =>
          b.id === data.broadcastId
            ? { ...b, latitude: data.latitude, longitude: data.longitude, message: data.message, distanceMeters: data.distanceMeters }
            : b
        )
      )
    } else if (type === 'broadcast.stopped') {
      setBroadcasts((prev) => prev.filter((b) => b.id !== data.broadcastId))
    }
  }, [wsEvent, user.id])

  async function startBroadcast() {
    if (!pos) { onToast('需要定位才能開始廣播', 'error'); return }
    setStarting(true)
    try {
      const { broadcast } = await api.startBroadcast({ latitude: pos.lat, longitude: pos.lng, message })
      setMyBroadcast(broadcast)
      setShowModal(false)
      setMessage('')
      onToast('廣播已開始！', 'success')
    } catch (err: any) {
      onToast(err.message, 'error')
    } finally {
      setStarting(false)
    }
  }

  async function stopBroadcast() {
    if (!myBroadcast) return
    try {
      await api.stopBroadcast(myBroadcast.id)
      setMyBroadcast(null)
      onToast('廣播已停止', 'info')
    } catch (err: any) {
      onToast(err.message, 'error')
    }
  }



  return (
    <div className="flex-1 overflow-y-auto px-4 py-4 pb-6 space-y-4">

      {/* My Broadcast Card */}
      <div className={`rounded-2xl border p-4 transition-all duration-300 ${
        myBroadcast
          ? 'bg-[#1E1435] border-[#7C3AED] shadow-lg shadow-purple-900/25'
          : 'bg-[#1A1A3A] border-[#2A2A4A]'
      }`}>
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <span className={`w-2 h-2 rounded-full ${myBroadcast ? 'bg-[#10B981] animate-pulse' : 'bg-[#475569]'}`} />
            <span className="text-sm font-semibold">
              {myBroadcast ? '廣播中' : '我的廣播'}
            </span>
          </div>
          {myBroadcast && (
            <span className="text-xs text-[#475569] flex items-center gap-1">
              <Clock size={11} /> {timeAgo(myBroadcast.createdAt)}
            </span>
          )}
        </div>

        {myBroadcast ? (
          <>
            {myBroadcast.message && (
              <p className="text-[#A78BFA] text-sm italic mb-3 leading-relaxed">
                "{myBroadcast.message}"
              </p>
            )}
            <div className="flex items-center gap-1.5 text-xs text-[#475569] mb-3">
              <MapPin size={11} />
              <span>附近玩家可以看到你的位置</span>
              <span className="ml-auto">每 5 分鐘自動續約</span>
            </div>
            <button
              onClick={stopBroadcast}
              className="w-full bg-[#F43F5E]/10 hover:bg-[#F43F5E]/20 border border-[#F43F5E]/30 text-[#F43F5E] py-2.5 rounded-xl text-sm font-semibold flex items-center justify-center gap-2 transition-colors cursor-pointer"
            >
              <X size={15} /> 停止廣播
            </button>
          </>
        ) : (
          <>
            {geoError && (
              <p className="text-[#F43F5E] text-xs mb-3 flex items-center gap-1.5">
                <WifiOff size={12} /> 定位失敗：{geoError}
              </p>
            )}
            <button
              onClick={() => setShowModal(true)}
              disabled={!pos}
              className="w-full bg-[#7C3AED] hover:bg-[#6D28D9] disabled:opacity-40 disabled:cursor-not-allowed text-white py-2.5 rounded-xl text-sm font-semibold flex items-center justify-center gap-2 transition-colors cursor-pointer shadow-lg shadow-purple-900/30"
            >
              <Radio size={16} />
              {!pos && !geoError ? '取得定位中...' : '開始廣播找牌友'}
            </button>
          </>
        )}
      </div>

      {/* Nearby header */}
      <div className="flex items-center justify-between">
        <h2 className="font-semibold text-[#E2E8F0] flex items-center gap-2">
          附近玩家
          {broadcasts.length > 0 && (
            <span className="text-xs bg-[#7C3AED]/20 text-[#A78BFA] px-2 py-0.5 rounded-full">
              {broadcasts.length}
            </span>
          )}
        </h2>
        <button
          onClick={loadData}
          disabled={loading}
          className="p-1 text-[#475569] hover:text-[#A78BFA] transition-colors cursor-pointer"
          aria-label="重新整理"
        >
          <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
        </button>
      </div>

      {/* No location */}
      {!pos && !geoError && (
        <div className="bg-[#1A1A3A] border border-[#2A2A4A] rounded-xl p-4 flex items-center gap-3">
          <MapPin size={20} className="text-[#F59E0B] shrink-0 animate-pulse" />
          <p className="text-sm text-[#94A3B8]">正在取得定位資訊...</p>
        </div>
      )}

      {/* Broadcast list */}
      {broadcasts.length === 0 && pos && !loading ? (
        <div className="text-center py-16">
          <div className="w-16 h-16 rounded-2xl bg-[#1A1A3A] border border-[#2A2A4A] flex items-center justify-center mx-auto mb-4">
            <Radio size={28} className="text-[#2A2A4A]" />
          </div>
          <p className="text-[#475569] text-sm">附近沒有廣播中的玩家</p>
          <p className="text-[#2A2A4A] text-xs mt-1">開始廣播，讓他們找到你！</p>
        </div>
      ) : (
        <div className="space-y-3">
          {broadcasts.map((b) => (
            <BroadcastCard key={b.id} broadcast={b} onToast={onToast} />
          ))}
        </div>
      )}

      {/* Start Broadcast Modal */}
      {showModal && (
        <div
          className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-end justify-center p-4"
          onClick={() => setShowModal(false)}
        >
          <div
            className="bg-[#1A1A3A] rounded-2xl p-6 w-full max-w-sm border border-[#2A2A4A] shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="font-bold text-[#E2E8F0] mb-4 flex items-center gap-2">
              <Radio size={18} className="text-[#7C3AED]" />
              開始廣播
            </h3>
            <div className="mb-5">
              <label className="block text-xs text-[#94A3B8] mb-2 font-semibold uppercase tracking-wide">
                訊息（選填）
              </label>
              <div className="relative">
                <input
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  maxLength={200}
                  className="w-full bg-[#252545] border border-[#2A2A4A] rounded-xl px-4 py-3 pr-12 text-sm text-[#E2E8F0] outline-none focus:border-[#7C3AED] transition-colors placeholder-[#475569]"
                  placeholder="例：找人打台灣麻將，歡迎新手"
                  autoFocus
                />
                <span className="absolute right-3 top-3.5 text-xs text-[#475569]">
                  {message.length}/200
                </span>
              </div>
            </div>
            {pos && (
              <p className="text-xs text-[#475569] mb-4 flex items-center gap-1.5">
                <MapPin size={11} />
                {pos.lat.toFixed(5)}, {pos.lng.toFixed(5)}
              </p>
            )}
            <div className="flex gap-3">
              <button
                onClick={() => setShowModal(false)}
                className="flex-1 bg-[#252545] hover:bg-[#2A2A4A] text-[#94A3B8] py-3 rounded-xl text-sm cursor-pointer transition-colors"
              >
                取消
              </button>
              <button
                onClick={startBroadcast}
                disabled={starting}
                className="flex-1 bg-[#7C3AED] hover:bg-[#6D28D9] disabled:opacity-50 text-white py-3 rounded-xl text-sm font-semibold flex items-center justify-center gap-2 cursor-pointer transition-colors"
              >
                <Send size={15} />
                {starting ? '廣播中...' : '開始'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function BroadcastCard({
  broadcast,
  onToast,
}: {
  broadcast: Broadcast
  onToast: (msg: string, type?: 'info' | 'success' | 'error') => void
}) {
  const [adding, setAdding] = useState(false)
  const name = broadcast.player?.displayName || '未知玩家'
  const initials = name.slice(0, 2).toUpperCase()

  async function sendRequest() {
    setAdding(true)
    try {
      await api.sendFriendRequest(broadcast.playerId)
      onToast('好友邀請已送出', 'success')
    } catch (err: any) {
      onToast(err.message, 'error')
    } finally {
      setAdding(false)
    }
  }

  return (
    <div className="bg-[#1A1A3A] border border-[#2A2A4A] rounded-xl p-4 hover:border-[#7C3AED]/40 transition-colors">
      <div className="flex items-start gap-3">
        <div className="w-10 h-10 rounded-xl bg-[#7C3AED]/20 flex items-center justify-center text-[#A78BFA] font-bold text-sm shrink-0">
          {initials}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between gap-2">
            <span className="font-semibold text-[#E2E8F0] truncate">{name}</span>
            {broadcast.distanceMeters !== undefined && (
              <span className="text-xs text-[#475569] shrink-0 flex items-center gap-0.5">
                <MapPin size={11} />
                {formatDist(broadcast.distanceMeters)}
              </span>
            )}
          </div>
          {broadcast.message && (
            <p className="text-sm text-[#A78BFA] mt-1 italic truncate">"{broadcast.message}"</p>
          )}
          <div className="flex items-center justify-between mt-2">
            <span className="text-xs text-[#475569]">{timeAgo(broadcast.createdAt)}</span>
            <button
              onClick={sendRequest}
              disabled={adding}
              className="text-xs bg-[#7C3AED]/10 hover:bg-[#7C3AED]/20 text-[#A78BFA] px-3 py-1 rounded-lg transition-colors cursor-pointer disabled:opacity-50 flex items-center gap-1"
            >
              <UserPlus size={12} /> 加好友
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
