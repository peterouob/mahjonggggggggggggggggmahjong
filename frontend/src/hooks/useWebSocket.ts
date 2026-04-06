import { useEffect, useRef, useCallback } from 'react'
import { WS_URL, MOCK_MODE } from '../api'

export interface WSEvent {
  type: string
  data?: any
}

export function useWebSocket(
  userId: string | null,
  onEvent: (event: WSEvent) => void
) {
  const wsRef = useRef<WebSocket | null>(null)
  const reconnectRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const reconnectDelayRef = useRef(1000)
  const onEventRef = useRef(onEvent)
  const activeRef = useRef(false)
  onEventRef.current = onEvent

  const connect = useCallback(() => {
    if (!userId || !activeRef.current) return

    const ws = new WebSocket(WS_URL(userId))
    wsRef.current = ws

    ws.onopen = () => {
      reconnectDelayRef.current = 1000 // reset backoff on success
    }

    ws.onmessage = (e) => {
      try {
        const event = JSON.parse(e.data) as WSEvent
        if (event.type !== 'pong') onEventRef.current(event)
      } catch {}
    }

    ws.onclose = () => {
      if (!activeRef.current) return
      // Exponential backoff: 1s → 2s → 4s → 8s → max 30s
      const delay = reconnectDelayRef.current
      reconnectDelayRef.current = Math.min(delay * 2, 30000)
      reconnectRef.current = setTimeout(connect, delay)
    }

    // onerror fires before onclose; let onclose handle reconnect
    ws.onerror = () => {}
  }, [userId])

  const send = useCallback((data: object) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(data))
    }
  }, [])

  useEffect(() => {
    if (!userId || MOCK_MODE) return
    activeRef.current = true
    reconnectDelayRef.current = 1000
    connect()
    return () => {
      activeRef.current = false
      clearTimeout(reconnectRef.current)
      wsRef.current?.close()
    }
  }, [userId, connect])

  return { send }
}
