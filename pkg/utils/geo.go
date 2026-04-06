package utils

import "math"

const earthRadiusMeters = 6_371_000.0

// HaversineDistance returns the great-circle distance in metres between two
// WGS-84 coordinates.
func HaversineDistance(lat1, lng1, lat2, lng2 float64) float64 {
	φ1 := lat1 * math.Pi / 180
	φ2 := lat2 * math.Pi / 180
	Δφ := (lat2 - lat1) * math.Pi / 180
	Δλ := (lng2 - lng1) * math.Pi / 180

	a := math.Sin(Δφ/2)*math.Sin(Δφ/2) +
		math.Cos(φ1)*math.Cos(φ2)*math.Sin(Δλ/2)*math.Sin(Δλ/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadiusMeters * c
}

// BlurCoordinates offsets a position by a random-looking but deterministic
// amount (±150 m) so that a waiting room's exact location is not revealed.
// The seed keeps the blur stable across calls for the same room.
func BlurCoordinates(lat, lng float64, seedMeters float64) (float64, float64) {
	// 150 m offset in degrees (rough approximation, good enough for UI blurring)
	const offsetDeg = 150.0 / 111_320.0
	// Use the seed to pick a fixed direction so the blur doesn't jitter
	angle := seedMeters * math.Pi / 180
	return lat + offsetDeg*math.Sin(angle), lng + offsetDeg*math.Cos(angle)
}
