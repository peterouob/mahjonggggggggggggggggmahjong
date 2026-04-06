package service

import (
	"context"
	"time"

	"mahjong/internal/domain"
	"mahjong/internal/repository"
	"mahjong/pkg/apierror"
	"mahjong/pkg/cache"
	"mahjong/pkg/utils"
)

const broadcastRadius = 5.0        // km – fixed MVP radius
const locationThresholdM = 50.0    // minimum movement to trigger an update event
const broadcastTTL = 10 * time.Minute

type BroadcastService struct {
	broadcastRepo *repository.BroadcastRepository
	userRepo      repository.UserRepo
	rdb           *cache.Redis
	notify        *NotificationService
}

func NewBroadcastService(
	broadcastRepo *repository.BroadcastRepository,
	userRepo repository.UserRepo,
	rdb *cache.Redis,
	notify *NotificationService,
) *BroadcastService {
	return &BroadcastService{
		broadcastRepo: broadcastRepo,
		userRepo:      userRepo,
		rdb:           rdb,
		notify:        notify,
	}
}

type StartBroadcastInput struct {
	Latitude  float64 `json:"latitude"  binding:"required"`
	Longitude float64 `json:"longitude" binding:"required"`
	Message   string  `json:"message"   binding:"max=200"`
}

func (s *BroadcastService) Start(ctx context.Context, userID string, in StartBroadcastInput) (*domain.Broadcast, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil || user == nil {
		return nil, apierror.NotFound("User not found")
	}

	// Account age restriction: must be >24 h old
	if !user.CanBroadcast() {
		return nil, apierror.BadRequest(apierror.CodeBroadcastAgeRestricted,
			"New accounts must be at least 24 hours old before broadcasting")
	}

	// Enforce single active broadcast per player (application-level; DB has no EXCLUDE in MySQL)
	existing, err := s.broadcastRepo.GetActiveByPlayerID(ctx, userID)
	if err != nil {
		return nil, apierror.Internal()
	}
	if existing != nil {
		return nil, apierror.Conflict(apierror.CodeBroadcastAlreadyActive,
			"You already have an active broadcast; stop it first")
	}

	b := &domain.Broadcast{
		PlayerID:  userID,
		Latitude:  in.Latitude,
		Longitude: in.Longitude,
		Status:    domain.BroadcastActive,
		Message:   in.Message,
		ExpiresAt: time.Now().Add(broadcastTTL),
	}
	if err := s.broadcastRepo.Create(ctx, b); err != nil {
		return nil, apierror.Internal()
	}

	// Index in Redis GeoSet and set TTL heartbeat key
	_ = s.rdb.GeoAddBroadcast(ctx, userID, in.Latitude, in.Longitude)
	_ = s.rdb.SetBroadcastTTL(ctx, userID)

	b.Player = user
	go s.notify.NotifyNearbyBroadcastStarted(ctx, b)

	return b, nil
}

type UpdateLocationInput struct {
	Latitude  float64 `json:"latitude"  binding:"required"`
	Longitude float64 `json:"longitude" binding:"required"`
}

func (s *BroadcastService) UpdateLocation(ctx context.Context, userID, broadcastID string, in UpdateLocationInput) error {
	b, err := s.broadcastRepo.GetByID(ctx, broadcastID)
	if err != nil || b == nil {
		return apierror.NotFound("Broadcast not found")
	}
	if b.PlayerID != userID {
		return apierror.Forbidden("Not your broadcast")
	}
	if b.Status != domain.BroadcastActive {
		return apierror.BadRequest(apierror.CodeBroadcastAlreadyActive, "Broadcast is not active")
	}

	moved := utils.HaversineDistance(b.Latitude, b.Longitude, in.Latitude, in.Longitude)

	b.Latitude = in.Latitude
	b.Longitude = in.Longitude
	b.ExpiresAt = time.Now().Add(broadcastTTL)

	if err := s.broadcastRepo.Update(ctx, b); err != nil {
		return apierror.Internal()
	}

	_ = s.rdb.GeoAddBroadcast(ctx, userID, in.Latitude, in.Longitude)
	_ = s.rdb.SetBroadcastTTL(ctx, userID)

	// Only propagate an event if movement exceeds 50 m threshold
	if moved >= locationThresholdM {
		user, _ := s.userRepo.GetByID(ctx, userID)
		b.Player = user
		go s.notify.NotifyNearbyBroadcastUpdated(ctx, b)
	}
	return nil
}

func (s *BroadcastService) Stop(ctx context.Context, userID, broadcastID string) error {
	b, err := s.broadcastRepo.GetByID(ctx, broadcastID)
	if err != nil || b == nil {
		return apierror.NotFound("Broadcast not found")
	}
	if b.PlayerID != userID {
		return apierror.Forbidden("Not your broadcast")
	}
	if b.Status != domain.BroadcastActive {
		return nil // idempotent
	}

	if err := s.broadcastRepo.Stop(ctx, broadcastID); err != nil {
		return apierror.Internal()
	}

	_ = s.rdb.GeoRemoveBroadcast(ctx, userID)
	_ = s.rdb.DeleteBroadcastTTL(ctx, userID)

	b.Status = domain.BroadcastStopped
	user, _ := s.userRepo.GetByID(ctx, userID)
	b.Player = user
	go s.notify.NotifyNearbyBroadcastStopped(ctx, b)

	return nil
}

func (s *BroadcastService) Heartbeat(ctx context.Context, userID, broadcastID string) error {
	b, err := s.broadcastRepo.GetByID(ctx, broadcastID)
	if err != nil || b == nil {
		return apierror.NotFound("Broadcast not found")
	}
	if b.PlayerID != userID {
		return apierror.Forbidden("Not your broadcast")
	}
	if b.Status != domain.BroadcastActive {
		return apierror.BadRequest(apierror.CodeBroadcastAlreadyActive, "Broadcast is not active")
	}

	b.ExpiresAt = time.Now().Add(broadcastTTL)
	_ = s.broadcastRepo.Update(ctx, b)
	_ = s.rdb.SetBroadcastTTL(ctx, userID)
	return nil
}

type BroadcastWithDistance struct {
	*domain.Broadcast
	DistanceMeters float64 `json:"distanceMeters"`
}

func (s *BroadcastService) GetNearby(ctx context.Context, userID string, lat, lng, radiusKm float64) ([]BroadcastWithDistance, error) {
	if radiusKm <= 0 || radiusKm > broadcastRadius {
		radiusKm = broadcastRadius
	}

	geoResults, err := s.rdb.GeoSearchBroadcasts(ctx, lat, lng, radiusKm)
	if err != nil {
		return nil, apierror.Internal()
	}

	results := make([]BroadcastWithDistance, 0, len(geoResults))
	for _, loc := range geoResults {
		playerID := loc.Name
		if playerID == userID {
			continue // don't show your own broadcast in nearby list
		}

		b, err := s.broadcastRepo.GetActiveByPlayerID(ctx, playerID)
		if err != nil || b == nil {
			continue
		}
		if err := s.loadPlayer(ctx, b); err != nil {
			continue
		}

		results = append(results, BroadcastWithDistance{
			Broadcast:      b,
			DistanceMeters: loc.Dist * 1000, // geo-redis returns km
		})
	}
	return results, nil
}

func (s *BroadcastService) GetMyActive(ctx context.Context, userID string) (*domain.Broadcast, error) {
	b, err := s.broadcastRepo.GetActiveByPlayerID(ctx, userID)
	if err != nil {
		return nil, apierror.Internal()
	}
	return b, nil
}

// StopActiveForPlayer is used internally by RoomService when a player joins a room.
func (s *BroadcastService) StopActiveForPlayer(ctx context.Context, playerID string) {
	b, _ := s.broadcastRepo.GetActiveByPlayerID(ctx, playerID)
	if b == nil {
		return
	}
	_ = s.broadcastRepo.Stop(ctx, b.ID)
	_ = s.rdb.GeoRemoveBroadcast(ctx, playerID)
	_ = s.rdb.DeleteBroadcastTTL(ctx, playerID)
}

func (s *BroadcastService) loadPlayer(ctx context.Context, b *domain.Broadcast) error {
	user, err := s.userRepo.GetByID(ctx, b.PlayerID)
	if err != nil {
		return err
	}
	b.Player = user
	return nil
}
