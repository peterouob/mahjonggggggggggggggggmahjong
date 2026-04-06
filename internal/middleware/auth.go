package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

const CtxUserID = "userID"

// NoAuth is the MVP identity middleware. It trusts the X-User-ID header
// directly — no JWT validation. Replace with JWT() before production.
// Returns 401 when the header is missing so callers always have a valid userID.
func NoAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetHeader("X-User-ID")
		if userID == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": gin.H{
				"code":    "UNAUTHORIZED",
				"message": "X-User-ID header is required",
			}})
			return
		}
		c.Set(CtxUserID, userID)
		c.Next()
	}
}

// GetUserID extracts the user ID set by NoAuth middleware.
func GetUserID(c *gin.Context) string {
	return c.GetString(CtxUserID)
}
