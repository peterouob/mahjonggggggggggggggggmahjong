import { useState, useEffect, useCallback } from 'react'
import { Radio, Layers, Users, UserCircle } from 'lucide-react'
import type { User, Toast, TabId } from './types'
import { useGeo } from './hooks/useGeo'
import { useWebSocket } from './hooks/useWebSocket'
import AuthPage from './pages/AuthPage'
import DiscoverPage from './pages/DiscoverPage'
import RoomsPage from './pages/RoomsPage'
import FriendsPage from './pages/FriendsPage'
import ProfilePage from './pages/ProfilePage'

// ─── Toast ────────────────────────────────────────────────────────────────────

function ToastContainer({
  toasts,
  onRemove,
}: {
  toasts: Toast[]
  onRemove: (id: string) => void
}) {
  return (
    <div className="fixed top-4 left-0 right-0 z-[100] flex flex-col gap-2 px-4 pointer-events-none max-w-md mx-auto">
      {toasts.map((t) => (
        <div
          key={t.id}
          onClick={() => onRemove(t.id)}
          className={`pointer-events-auto px-4 py-3 rounded-xl shadow-xl text-sm font-semibold flex items-center justify-between gap-3 border cursor-pointer transition-all duration-300 ${
            t.type === 'success' ? 'bg-[#0A2318] border-[#10B981]/30 text-[#10B981]' :
            t.type === 'error'   ? 'bg-[#250A0D] border-[#F43F5E]/30 text-[#F43F5E]' :
            t.type === 'warning' ? 'bg-[#231A07] border-[#F59E0B]/30 text-[#F59E0B]' :
                                   'bg-[#1A1A3A] border-[#2A2A4A] text-[#E2E8F0]'
          }`}
        >
          <span className="leading-snug">{t.message}</span>
          <span className="opacity-50 shrink-0 text-base leading-none">×</span>
        </div>
      ))}
    </div>
  )
}

// ─── App ──────────────────────────────────────────────────────────────────────

export default function App() {
  const [user, setUser] = useState<User | null>(() => {
    try {
      return JSON.parse(localStorage.getItem('user') || 'null')
    } catch {
      return null
    }
  })
  const [tab, setTab] = useState<TabId>('discover')
  const [toasts, setToasts] = useState<Toast[]>([])
  const [wsEvent, setWsEvent] = useState<{ type: string; data?: any } | null>(null)
  const [friendBadge, setFriendBadge] = useState(0)

  const { pos, error: geoError } = useGeo()
  const { send } = useWebSocket(user?.id ?? null, setWsEvent)

  // Send location to WS hub whenever position changes
  useEffect(() => {
    if (!user || !pos) return
    send({ type: 'update_location', lat: pos.lat, lng: pos.lng })
  }, [pos?.lat, pos?.lng, !!user])

  // Keep WS alive
  useEffect(() => {
    if (!user) return
    const id = setInterval(() => send({ type: 'ping' }), 25000)
    return () => clearInterval(id)
  }, [!!user, send])

  const addToast = useCallback(
    (message: string, type: Toast['type'] = 'info') => {
      const id = Math.random().toString(36).slice(2)
      setToasts((p) => [...p.slice(-4), { id, message, type }])
      setTimeout(() => setToasts((p) => p.filter((t) => t.id !== id)), 4000)
    },
    []
  )

  function removeToast(id: string) {
    setToasts((p) => p.filter((t) => t.id !== id))
  }

  function handleAuth(u: User) {
    setUser(u)
  }

  function handleLogout() {
    localStorage.removeItem('userId')
    localStorage.removeItem('user')
    setUser(null)
    setTab('discover')
    addToast('已登出', 'info')
  }

  // ── Auth gate ───────────────────────────────────────────────────────────────
  if (!user) {
    return (
      <>
        <ToastContainer toasts={toasts} onRemove={removeToast} />
        <AuthPage onAuth={handleAuth} onToast={addToast} />
      </>
    )
  }

  // ── Tab definitions ─────────────────────────────────────────────────────────
  const tabs: { id: TabId; label: string; icon: React.ElementType; badge?: number }[] = [
    { id: 'discover', label: '探索', icon: Radio },
    { id: 'rooms',    label: '房間', icon: Layers },
    { id: 'friends',  label: '好友', icon: Users, badge: friendBadge },
    { id: 'profile',  label: '我',   icon: UserCircle },
  ]

  return (
    <div className="h-full flex flex-col bg-[#0F0F23] max-w-md mx-auto">
      <ToastContainer toasts={toasts} onRemove={removeToast} />

      {/* Header */}
      <header className="shrink-0 bg-[#1A1A3A] border-b border-[#2A2A4A] px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="w-7 h-7 rounded-lg bg-[#7C3AED] flex items-center justify-center shadow-md shadow-purple-900/40">
            <Layers size={16} className="text-white" />
          </div>
          <span className="font-bold text-[#E2E8F0] tracking-widest text-sm">麻將找人</span>
        </div>
        <div className="flex items-center gap-2">
          {pos && (
            <span className="text-xs text-[#10B981] flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-[#10B981] animate-pulse" />
              定位中
            </span>
          )}
          <div className="w-7 h-7 rounded-lg bg-[#7C3AED]/20 flex items-center justify-center text-[#A78BFA] text-xs font-bold">
            {user.displayName.slice(0, 1)}
          </div>
        </div>
      </header>

      {/* Page */}
      <main className="flex-1 flex flex-col overflow-hidden">
        {tab === 'discover' && (
          <DiscoverPage
            user={user}
            pos={pos}
            geoError={geoError}
            onToast={addToast}
            wsEvent={wsEvent}
          />
        )}
        {tab === 'rooms' && (
          <RoomsPage user={user} pos={pos} onToast={addToast} wsEvent={wsEvent} />
        )}
        {tab === 'friends' && (
          <FriendsPage
            user={user}
            onToast={addToast}
            wsEvent={wsEvent}
            onBadge={setFriendBadge}
          />
        )}
        {tab === 'profile' && (
          <ProfilePage user={user} onLogout={handleLogout} onToast={addToast} />
        )}
      </main>

      {/* Bottom Nav */}
      <nav className="shrink-0 bg-[#1A1A3A] border-t border-[#2A2A4A] px-2 py-2 flex safe-bottom">
        {tabs.map(({ id, label, icon: Icon, badge }) => {
          const active = tab === id
          return (
            <button
              key={id}
              onClick={() => setTab(id)}
              className={`flex-1 flex flex-col items-center gap-1 py-1.5 rounded-xl transition-colors cursor-pointer relative ${
                active ? 'text-[#A78BFA]' : 'text-[#475569] hover:text-[#94A3B8]'
              }`}
              aria-label={label}
            >
              <div className="relative">
                <Icon size={22} strokeWidth={active ? 2.5 : 1.8} />
                {!!badge && badge > 0 && (
                  <span className="absolute -top-1 -right-1.5 bg-[#F43F5E] text-white text-[10px] font-bold rounded-full w-4 h-4 flex items-center justify-center leading-none">
                    {badge > 9 ? '9+' : badge}
                  </span>
                )}
              </div>
              <span className={`text-[10px] font-semibold tracking-wide ${active ? 'text-[#A78BFA]' : ''}`}>
                {label}
              </span>
              {active && (
                <span className="absolute bottom-0 left-1/2 -translate-x-1/2 w-4 h-0.5 bg-[#7C3AED] rounded-full" />
              )}
            </button>
          )
        })}
      </nav>
    </div>
  )
}

