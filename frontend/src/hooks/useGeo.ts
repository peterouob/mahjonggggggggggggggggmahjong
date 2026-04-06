import { useState, useEffect } from 'react'
import type { GeoPos } from '../types'
import { MOCK_MODE } from '../api'

// Mock location: Taipei Da'an District
const MOCK_POS: GeoPos = { lat: 25.0330, lng: 121.5654 }

export function useGeo() {
  const [pos, setPos] = useState<GeoPos | null>(MOCK_MODE ? MOCK_POS : null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (MOCK_MODE) return  // use the seeded mock position

    if (!navigator.geolocation) {
      setError('瀏覽器不支援定位功能')
      return
    }
    const watchId = navigator.geolocation.watchPosition(
      (p) => {
        setPos({ lat: p.coords.latitude, lng: p.coords.longitude })
        setError(null)
      },
      (e) => setError(e.message),
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 30000 }
    )
    return () => navigator.geolocation.clearWatch(watchId)
  }, [])

  return { pos, error }
}
