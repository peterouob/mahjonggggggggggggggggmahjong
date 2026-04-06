package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"mahjong/internal/config"
	"mahjong/internal/handler"
	"mahjong/internal/hub"
	"mahjong/internal/repository"
	"mahjong/internal/router"
	"mahjong/internal/service"
	"mahjong/pkg/cache"
	"mahjong/pkg/database"

	"github.com/gin-gonic/gin"
)

func main() {
	// ── Config ─────────────────────────────────────────────────────────────────
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	gin.SetMode(cfg.Server.GinMode)

	// ── Infrastructure ─────────────────────────────────────────────────────────
	db, err := database.Connect(cfg.Database)
	if err != nil {
		log.Fatalf("mysql: %v", err)
	}

	rdb, err := cache.NewRedis(cfg.Redis)
	if err != nil {
		log.Fatalf("redis: %v", err)
	}

	// ── Repositories ───────────────────────────────────────────────────────────
	var userRepo repository.UserRepo
	if os.Getenv("MOCK_USERS") == "true" {
		userRepo = repository.NewMockUserRepository()
		log.Println("⚠️  MOCK_USERS=true — using in-memory users (user-1 … user-5)")
	} else {
		userRepo = repository.NewUserRepository(db)
	}
	broadcastRepo := repository.NewBroadcastRepository(db)
	roomRepo := repository.NewRoomRepository(db)
	socialRepo := repository.NewSocialRepository(db)

	// ── Services ───────────────────────────────────────────────────────────────
	notifySvc := service.NewNotificationService(rdb)
	authSvc := service.NewAuthService(userRepo)
	broadcastSvc := service.NewBroadcastService(broadcastRepo, userRepo, rdb, notifySvc)
	roomSvc := service.NewRoomService(roomRepo, userRepo, socialRepo, broadcastSvc, notifySvc)
	socialSvc := service.NewSocialService(socialRepo, userRepo, rdb, notifySvc)

	// ── WebSocket hub ──────────────────────────────────────────────────────────
	wsHub := hub.New(rdb)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go wsHub.Run(ctx)

	// ── Handlers & router ──────────────────────────────────────────────────────
	authH := handler.NewAuthHandler(authSvc)
	broadcastH := handler.NewBroadcastHandler(broadcastSvc)
	roomH := handler.NewRoomHandler(roomSvc)
	socialH := handler.NewSocialHandler(socialSvc)
	wsH := handler.NewWSHandler(wsHub)

	engine := router.Setup(rdb, authH, broadcastH, roomH, socialH, wsH)

	// ── HTTP server with graceful shutdown ─────────────────────────────────────
	srv := &http.Server{
		Addr:        fmt.Sprintf(":%s", cfg.Server.Port),
		Handler:     engine,
		IdleTimeout: 60 * time.Second,
	}

	go func() {
		log.Printf("server: listening on %s", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("server: shutting down…")
	cancel() // stop the WebSocket hub

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("server: forced shutdown: %v", err)
	}
	log.Println("server: exited cleanly")
}
