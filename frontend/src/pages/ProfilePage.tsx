import { useState } from 'react'
import { LogOut, Clock, Copy, CheckCircle } from 'lucide-react'
import type { User } from '../types'

interface Props {
  user: User
  onLogout: () => void
  onToast: (msg: string, type?: 'info' | 'success' | 'error') => void
}

export default function ProfilePage({ user, onLogout, onToast }: Props) {
  const [copied, setCopied] = useState(false)

  const initials = user.displayName.slice(0, 2).toUpperCase()

  function copyId() {
    navigator.clipboard.writeText(user.id).then(() => {
      setCopied(true)
      onToast('使用者 ID 已複製', 'success')
      setTimeout(() => setCopied(false), 2000)
    })
  }

  return (
    <div className="flex-1 overflow-y-auto px-4 py-4 pb-6 space-y-4">

      {/* Avatar + name */}
      <div className="bg-[#1A1A3A] border border-[#2A2A4A] rounded-2xl p-5">
        <div className="flex items-center gap-4 mb-5">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#7C3AED] to-[#A78BFA] flex items-center justify-center text-white font-bold text-2xl shadow-lg shadow-purple-900/40 shrink-0">
            {initials}
          </div>
          <div>
            <h2 className="font-bold text-[#E2E8F0] text-lg leading-tight">{user.displayName}</h2>
            <p className="text-[#94A3B8] text-sm">@{user.username}</p>
            <p className="text-[#475569] text-xs mt-0.5">{user.email}</p>
          </div>
        </div>

        {/* User ID copy box */}
        <div className="bg-[#252545] rounded-xl p-3">
          <p className="text-xs text-[#475569] mb-1.5">使用者 ID（分享給朋友讓他們加你）</p>
          <div className="flex items-center gap-2">
            <p className="text-xs text-[#94A3B8] font-mono flex-1 truncate">{user.id}</p>
            <button
              onClick={copyId}
              className="shrink-0 text-[#475569] hover:text-[#A78BFA] cursor-pointer transition-colors"
              aria-label="複製 ID"
            >
              {copied ? (
                <CheckCircle size={16} className="text-[#10B981]" />
              ) : (
                <Copy size={16} />
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Info rows */}
      <div className="bg-[#1A1A3A] border border-[#2A2A4A] rounded-2xl overflow-hidden">
        <div className="px-4 py-3.5 flex items-center justify-between">
          <div className="flex items-center gap-2.5 text-sm text-[#94A3B8]">
            <Clock size={15} className="text-[#475569]" />
            帳號建立時間
          </div>
          <span className="text-sm text-[#E2E8F0]">
            {new Date(user.createdAt).toLocaleDateString('zh-TW', {
              year: 'numeric', month: 'long', day: 'numeric',
            })}
          </span>
        </div>
      </div>

      {/* MVP notice */}
      <div className="bg-[#1A1A3A] border border-[#2A2A4A] rounded-xl px-4 py-3 text-center">
        <p className="text-xs text-[#2A2A4A] leading-relaxed">
          Beta 版本 · 目前使用帳號密碼認證<br />
          完整 OAuth（Apple / Google）即將推出
        </p>
      </div>

      {/* Logout */}
      <button
        onClick={onLogout}
        className="w-full bg-[#F43F5E]/10 hover:bg-[#F43F5E]/20 border border-[#F43F5E]/30 text-[#F43F5E] py-3.5 rounded-xl font-semibold cursor-pointer transition-colors flex items-center justify-center gap-2"
      >
        <LogOut size={18} /> 登出
      </button>
    </div>
  )
}
