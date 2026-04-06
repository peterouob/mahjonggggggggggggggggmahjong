import { useState } from 'react'
import { LogIn, Layers } from 'lucide-react'
import { api, MOCK_MODE } from '../api'
import type { User } from '../types'

interface Props {
  onAuth: (user: User) => void
  onToast: (msg: string, type?: 'success' | 'error' | 'info') => void
}

const TEST_PASSWORD = 'test1234'

export default function AuthPage({ onAuth, onToast }: Props) {
  const [name, setName] = useState('')
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!name.trim()) return
    setLoading(true)
    const username = name.trim().toLowerCase().replace(/\s+/g, '_')

    if (MOCK_MODE) {
      // Bypass network — create a local user directly
      const user: User = {
        id: `local-${username}`,
        username,
        email: `${username}@local`,
        displayName: name.trim(),
        avatarUrl: '',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }
      localStorage.setItem('userId', user.id)
      localStorage.setItem('user', JSON.stringify(user))
      onAuth(user)
      onToast(`歡迎, ${user.displayName}!`, 'success')
      setLoading(false)
      return
    }

    try {
      // Try register first; if username taken, fall back to login.
      let user: User
      try {
        const res = await api.register({
          username,
          email: `${username}@test.local`,
          password: TEST_PASSWORD,
          displayName: name.trim(),
        })
        user = res.user
        onToast(`歡迎加入, ${user.displayName}!`, 'success')
      } catch {
        const res = await api.login({ username, password: TEST_PASSWORD })
        user = res.user
        onToast(`歡迎回來, ${user.displayName}!`, 'success')
      }
      localStorage.setItem('userId', user.id)
      localStorage.setItem('user', JSON.stringify(user))
      onAuth(user)
    } catch (err: any) {
      onToast(err.message, 'error')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#0F0F23] flex flex-col items-center justify-center px-5">
      {/* Logo */}
      <div className="mb-10 flex flex-col items-center gap-3">
        <div className="w-[72px] h-[72px] rounded-2xl bg-gradient-to-br from-[#7C3AED] to-[#A78BFA] flex items-center justify-center shadow-xl shadow-purple-900/50">
          <Layers size={34} className="text-white" />
        </div>
        <h1 className="text-3xl font-bold text-[#E2E8F0] tracking-widest">麻將找人</h1>
        <p className="text-[#94A3B8] text-sm">找到你附近的牌友，開始一局好牌</p>
      </div>

      <form onSubmit={handleSubmit} className="w-full max-w-sm space-y-4">
        <div>
          <label className="block text-xs text-[#94A3B8] mb-1.5 font-semibold tracking-wide uppercase">
            你的名字
          </label>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full bg-[#1A1A3A] border border-[#2A2A4A] rounded-xl px-4 py-3 text-[#E2E8F0] text-sm outline-none focus:border-[#7C3AED] transition-colors placeholder-[#475569]"
            placeholder="輸入名字即可進入"
            autoFocus
            required
          />
        </div>
        <button
          type="submit"
          disabled={loading || !name.trim()}
          className="w-full bg-[#7C3AED] hover:bg-[#6D28D9] disabled:opacity-50 text-white py-3.5 rounded-xl font-semibold flex items-center justify-center gap-2 transition-colors cursor-pointer shadow-lg shadow-purple-900/30"
        >
          <LogIn size={18} />
          {loading ? '進入中...' : '進入'}
        </button>
      </form>
    </div>
  )
}
