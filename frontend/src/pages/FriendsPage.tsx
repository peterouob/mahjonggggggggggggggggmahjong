import { useState, useEffect } from 'react'
import {
  UserCheck, UserX, UserPlus, Trash2, ShieldOff, Search, ChevronDown, Users,
} from 'lucide-react'
import { api } from '../api'
import type { User, FriendRequest } from '../types'

interface Props {
  user: User
  onToast: (msg: string, type?: 'info' | 'success' | 'error') => void
  wsEvent: { type: string; data?: any } | null
  onBadge: (count: number) => void
}

export default function FriendsPage({ user: _user, onToast, wsEvent, onBadge }: Props) {
  const [friends, setFriends] = useState<User[]>([])
  const [requests, setRequests] = useState<FriendRequest[]>([])
  const [loading, setLoading] = useState(false)
  const [sendToId, setSendToId] = useState('')
  const [sending, setSending] = useState(false)
  const [search, setSearch] = useState('')

  async function loadData() {
    setLoading(true)
    try {
      const [fr, rq] = await Promise.all([
        api.getFriends().catch(() => ({ friends: [] })),
        api.getFriendRequests().catch(() => ({ requests: [] })),
      ])
      setFriends(fr.friends ?? [])
      const reqs = rq.requests ?? []
      setRequests(reqs)
      onBadge(reqs.length)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { loadData() }, [])

  useEffect(() => {
    if (!wsEvent) return
    if (wsEvent.type === 'friend.request') {
      loadData()
      onToast('收到新的好友邀請！', 'info')
    } else if (wsEvent.type === 'friend.accepted') {
      loadData()
      onToast('好友邀請已被接受！', 'success')
    }
  }, [wsEvent])

  async function sendRequest() {
    const id = sendToId.trim()
    if (!id) return
    setSending(true)
    try {
      await api.sendFriendRequest(id)
      setSendToId('')
      onToast('好友邀請已送出', 'success')
    } catch (err: any) {
      onToast(err.message, 'error')
    } finally {
      setSending(false)
    }
  }

  async function accept(id: string) {
    try {
      await api.acceptFriendRequest(id)
      setRequests((p) => p.filter((r) => r.id !== id))
      onBadge(Math.max(0, requests.length - 1))
      onToast('已接受好友邀請！', 'success')
      loadData()
    } catch (err: any) { onToast(err.message, 'error') }
  }

  async function reject(id: string) {
    try {
      await api.rejectFriendRequest(id)
      setRequests((p) => p.filter((r) => r.id !== id))
      onBadge(Math.max(0, requests.length - 1))
      onToast('已拒絕好友邀請', 'info')
    } catch (err: any) { onToast(err.message, 'error') }
  }

  async function removeFriend(friendId: string) {
    try {
      await api.removeFriend(friendId)
      setFriends((p) => p.filter((f) => f.id !== friendId))
      onToast('已移除好友', 'info')
    } catch (err: any) { onToast(err.message, 'error') }
  }

  async function blockUser(uid: string) {
    try {
      await api.blockUser(uid)
      setFriends((p) => p.filter((f) => f.id !== uid))
      onToast('已封鎖使用者', 'info')
    } catch (err: any) { onToast(err.message, 'error') }
  }

  const filtered = friends.filter(
    (f) =>
      f.displayName.toLowerCase().includes(search.toLowerCase()) ||
      f.username.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="flex-1 overflow-y-auto px-4 py-4 pb-6 space-y-5">

      {/* Send Friend Request */}
      <div className="bg-[#1A1A3A] border border-[#2A2A4A] rounded-2xl p-4">
        <p className="text-xs text-[#94A3B8] font-semibold uppercase tracking-wide mb-3">
          送出好友邀請
        </p>
        <div className="flex gap-2">
          <input
            value={sendToId}
            onChange={(e) => setSendToId(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && sendRequest()}
            className="flex-1 bg-[#252545] border border-[#2A2A4A] rounded-xl px-4 py-2.5 text-sm text-[#E2E8F0] outline-none focus:border-[#7C3AED] transition-colors placeholder-[#475569]"
            placeholder="輸入對方的使用者 ID"
          />
          <button
            onClick={sendRequest}
            disabled={sending || !sendToId.trim()}
            className="bg-[#7C3AED] hover:bg-[#6D28D9] disabled:opacity-40 disabled:cursor-not-allowed text-white w-11 rounded-xl flex items-center justify-center cursor-pointer transition-colors"
            aria-label="送出"
          >
            <UserPlus size={17} />
          </button>
        </div>
        <p className="text-xs text-[#2A2A4A] mt-2">可在「我」頁面複製自己的使用者 ID 分享給朋友</p>
      </div>

      {/* Pending Requests */}
      {requests.length > 0 && (
        <section>
          <h2 className="font-semibold text-[#E2E8F0] mb-3 flex items-center gap-2">
            好友邀請
            <span className="bg-[#F43F5E] text-white text-xs px-1.5 py-0.5 rounded-full font-bold min-w-[20px] text-center">
              {requests.length}
            </span>
          </h2>
          <div className="space-y-2">
            {requests.map((req) => {
              const name = req.fromUser?.displayName || req.initiatorId
              const initials = name.slice(0, 2).toUpperCase()
              return (
                <div
                  key={req.id}
                  className="bg-[#1A1A3A] border border-[#7C3AED]/30 rounded-xl p-4 flex items-center gap-3"
                >
                  <div className="w-10 h-10 rounded-xl bg-[#7C3AED]/20 flex items-center justify-center text-[#A78BFA] font-bold text-sm shrink-0">
                    {initials}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-[#E2E8F0] text-sm truncate">{name}</p>
                    <p className="text-xs text-[#475569]">想加你為好友</p>
                  </div>
                  <div className="flex gap-2 shrink-0">
                    <button
                      onClick={() => accept(req.id)}
                      className="w-9 h-9 bg-[#10B981]/15 hover:bg-[#10B981]/25 border border-[#10B981]/30 text-[#10B981] rounded-lg flex items-center justify-center cursor-pointer transition-colors"
                      aria-label="接受"
                    >
                      <UserCheck size={16} />
                    </button>
                    <button
                      onClick={() => reject(req.id)}
                      className="w-9 h-9 bg-[#F43F5E]/10 hover:bg-[#F43F5E]/20 border border-[#F43F5E]/30 text-[#F43F5E] rounded-lg flex items-center justify-center cursor-pointer transition-colors"
                      aria-label="拒絕"
                    >
                      <UserX size={16} />
                    </button>
                  </div>
                </div>
              )
            })}
          </div>
        </section>
      )}

      {/* Friends List */}
      <section>
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-semibold text-[#E2E8F0] flex items-center gap-2">
            好友列表
            <span className="text-xs text-[#475569]">{friends.length}</span>
          </h2>
          {loading && <div className="w-4 h-4 border-2 border-[#7C3AED] border-t-transparent rounded-full animate-spin" />}
        </div>

        {friends.length > 3 && (
          <div className="bg-[#1A1A3A] border border-[#2A2A4A] rounded-xl px-4 py-2.5 flex items-center gap-2 mb-3">
            <Search size={15} className="text-[#475569]" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="flex-1 bg-transparent text-sm text-[#E2E8F0] outline-none placeholder-[#475569]"
              placeholder="搜尋好友..."
            />
          </div>
        )}

        {filtered.length === 0 ? (
          <div className="text-center py-12">
            <div className="w-14 h-14 rounded-2xl bg-[#1A1A3A] border border-[#2A2A4A] flex items-center justify-center mx-auto mb-3">
              <Users size={24} className="text-[#2A2A4A]" />
            </div>
            <p className="text-[#475569] text-sm">
              {friends.length === 0 ? '還沒有好友' : '找不到符合的好友'}
            </p>
            {friends.length === 0 && (
              <p className="text-[#2A2A4A] text-xs mt-1">在探索頁面找到玩家後加好友！</p>
            )}
          </div>
        ) : (
          <div className="space-y-2">
            {filtered.map((f) => (
              <FriendRow key={f.id} friend={f} onRemove={removeFriend} onBlock={blockUser} />
            ))}
          </div>
        )}
      </section>
    </div>
  )
}

function FriendRow({
  friend, onRemove, onBlock,
}: {
  friend: User
  onRemove: (id: string) => void
  onBlock: (id: string) => void
}) {
  const [open, setOpen] = useState(false)
  const initials = friend.displayName.slice(0, 2).toUpperCase()

  return (
    <div className="bg-[#1A1A3A] border border-[#2A2A4A] rounded-xl overflow-hidden">
      <div
        className="p-3.5 flex items-center gap-3 cursor-pointer hover:bg-[#252545] transition-colors"
        onClick={() => setOpen((p) => !p)}
      >
        <div className="w-9 h-9 rounded-xl bg-[#7C3AED]/20 flex items-center justify-center text-[#A78BFA] font-bold text-sm shrink-0">
          {initials}
        </div>
        <div className="flex-1 min-w-0">
          <p className="font-semibold text-[#E2E8F0] text-sm truncate">{friend.displayName}</p>
          <p className="text-xs text-[#475569]">@{friend.username}</p>
        </div>
        <ChevronDown
          size={15}
          className={`text-[#475569] transition-transform duration-200 ${open ? 'rotate-180' : ''}`}
        />
      </div>
      {open && (
        <div className="px-3.5 pb-3.5 flex gap-2 border-t border-[#2A2A4A] pt-3">
          <button
            onClick={() => onRemove(friend.id)}
            className="flex-1 bg-[#252545] hover:bg-[#2A2A4A] text-[#94A3B8] py-2 rounded-lg text-xs cursor-pointer transition-colors flex items-center justify-center gap-1.5"
          >
            <Trash2 size={13} /> 移除好友
          </button>
          <button
            onClick={() => onBlock(friend.id)}
            className="flex-1 bg-[#F43F5E]/10 hover:bg-[#F43F5E]/20 border border-[#F43F5E]/30 text-[#F43F5E] py-2 rounded-lg text-xs cursor-pointer transition-colors flex items-center justify-center gap-1.5"
          >
            <ShieldOff size={13} /> 封鎖
          </button>
        </div>
      )}
    </div>
  )
}
