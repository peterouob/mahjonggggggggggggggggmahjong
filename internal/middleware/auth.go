package middleware

import (
	"log"

	"github.com/gin-gonic/gin"
)

const CtxUserID = "userID"

// NoAuth is the MVP identity middleware. It trusts the X-User-ID header
// directly — no JWT validation. Replace with JWT() before production.
func NoAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetHeader("X-User-ID")
		if userID == "" {
			log.Println("No X-User-ID")
		}
		c.Set(CtxUserID, userID)
		c.Next()
	}
}

// GetUserID extracts the user ID set by NoAuth middleware.
func GetUserID(c *gin.Context) string {
	return c.GetString(CtxUserID)
}
