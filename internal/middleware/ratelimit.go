package middleware

import (
	"time"

	"mahjong/pkg/cache"

	"github.com/gin-gonic/gin"
)

// RateLimit creates a per-user, per-action fixed-window rate limiter backed by Redis.
// Call it per route with the specific action name and limit defined in the spec.
//
// Example:
//
//	router.POST("/broadcasts", RateLimit(rdb, "startBroadcast", 5, time.Minute), handler)
func RateLimit(rdb *cache.Redis, action string, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Use userID if authenticated, fall back to IP for public routes
		key := c.GetString(CtxUserID)
		if key == "" {
			key = c.ClientIP()
		}

		allowed, err := rdb.RateLimit(c.Request.Context(), key, action, limit, window)
		if err != nil {
			// Fail open: if Redis is unavailable, don't block legitimate requests
			c.Next()
			return
		}
		if !allowed {
			c.AbortWithStatusJSON(429, gin.H{"error": gin.H{
				"code":    "RATE_LIMITED",
				"message": "Too many requests, please slow down",
			}})
			return
		}
		c.Next()
	}
}
