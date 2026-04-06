package router

import (
	"net/http"
	"time"

	"mahjong/internal/handler"
	"mahjong/internal/middleware"
	"mahjong/pkg/cache"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func Setup(
	rdb *cache.Redis,
	authH *handler.AuthHandler,
	broadcastH *handler.BroadcastHandler,
	roomH *handler.RoomHandler,
	socialH *handler.SocialHandler,
	wsH *handler.WSHandler,
) *gin.Engine {
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization", "X-User-ID"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowWebSockets:  true,
		MaxAge:           12 * time.Hour,
	}))
	// Health check (used by load balancer and Docker healthcheck)
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// WebSocket (?user_id= query param — no token required in MVP)
	r.GET("/ws", wsH.ServeWS)

	api := r.Group("/api/v1")

	// ── Auth (public) ──────────────────────────────────────────────────────────
	auth := api.Group("/auth")
	{
		auth.POST("/register", authH.Register)
		auth.POST("/login", authH.Login)
	}

	// ── Routes — identity via X-User-ID header (MVP; no JWT) ──────────────────
	protected := api.Group("", middleware.NoAuth())

	// Broadcasts
	bc := protected.Group("/broadcasts")
	{
		bc.POST("",
			middleware.RateLimit(rdb, "startBroadcast", 5, time.Minute),
			broadcastH.Start,
		)
		bc.GET("/nearby", broadcastH.GetNearby)
		bc.GET("/me", broadcastH.GetMine)
		bc.PATCH("/:id/location",
			middleware.RateLimit(rdb, "updateLocation", 60, time.Minute),
			broadcastH.UpdateLocation,
		)
		bc.POST("/:id/heartbeat",
			middleware.RateLimit(rdb, "heartbeat", 20, time.Minute),
			broadcastH.Heartbeat,
		)
		bc.DELETE("/:id", broadcastH.Stop)
	}

	// Rooms
	rooms := protected.Group("/rooms")
	{
		rooms.GET("", roomH.List)
		rooms.POST("",
			middleware.RateLimit(rdb, "createRoom", 3, time.Minute),
			roomH.Create,
		)
		rooms.GET("/nearby", roomH.ListNearby)
		rooms.GET("/me", roomH.GetMine)
		rooms.GET("/:id", roomH.GetByID)
		rooms.POST("/:id/join",
			middleware.RateLimit(rdb, "joinRoom", 10, time.Minute),
			roomH.Join,
		)
		rooms.POST("/:id/leave", roomH.Leave)
		rooms.DELETE("/:id", roomH.Dissolve)
	}

	// Friends
	friends := protected.Group("/friends")
	{
		friends.GET("", socialH.ListFriends)
		friends.GET("/requests", socialH.ListPendingRequests)
		friends.POST("/requests",
			middleware.RateLimit(rdb, "sendFriendRequest", 20, time.Hour),
			socialH.SendRequest,
		)
		friends.PUT("/requests/:id/accept", socialH.AcceptRequest)
		friends.PUT("/requests/:id/reject", socialH.RejectRequest)
		friends.DELETE("/:id", socialH.RemoveFriend)
	}

	// Users
	users := protected.Group("/users")
	{
		users.POST("/:id/block", socialH.BlockUser)
		users.DELETE("/:id/block", socialH.UnblockUser)
	}

	return r
}
