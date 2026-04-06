package service

import (
	"context"
	"time"

	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/domain"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/repository"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/pkg/apierror"
)

const maxFriends = 200

type RoomService struct {
	roomRepo     repository.RoomRepo
	userRepo     repository.UserRepo
	socialRepo   repository.SocialRepo
	broadcastSvc *BroadcastService
	notify       *NotificationService
}

func NewRoomService(
	roomRepo repository.RoomRepo,
	userRepo repository.UserRepo,
	socialRepo repository.SocialRepo,
	broadcastSvc *BroadcastService,
	notify *NotificationService,
) *RoomService {
	return &RoomService{
		roomRepo:     roomRepo,
		userRepo:     userRepo,
		socialRepo:   socialRepo,
		broadcastSvc: broadcastSvc,
		notify:       notify,
	}
}

type CreateRoomInput struct {
	Name      string          `json:"name"      binding:"required,min=1,max=100"`
	PlaceName string          `json:"placeName" binding:"max=100"`
	GameRule  domain.GameRule `json:"gameRule"`
	IsPublic  *bool           `json:"isPublic"`
	Latitude  float64         `json:"latitude"  binding:"required"`
	Longitude float64         `json:"longitude" binding:"required"`
}

func (s *RoomService) Create(ctx context.Context, hostID string, in CreateRoomInput) (*domain.Room, error) {
	user, err := s.userRepo.GetByID(ctx, hostID)
	if err != nil || user == nil {
		return nil, apierror.NotFound("User not found")
	}
	// Reuse account-age gate that guards broadcasting
	if !user.CanBroadcast() {
		return nil, apierror.BadRequest(apierror.CodeBroadcastAgeRestricted,
			"New accounts must be at least 24 hours old before creating a room")
	}

	// Enforce: player can be in only one active room
	if existing, _ := s.roomRepo.GetActiveRoomByPlayerID(ctx, hostID); existing != nil {
		return nil, apierror.Conflict(apierror.CodeAlreadyInRoom, "You are already in an active room")
	}

	isPublic := true
	if in.IsPublic != nil {
		isPublic = *in.IsPublic
	}
	gameRule := in.GameRule
	if gameRule == "" {
		gameRule = domain.GameRuleTaiwan
	}

	room := &domain.Room{
		HostID:     hostID,
		Name:       in.Name,
		PlaceName:  in.PlaceName,
		GameRule:   gameRule,
		IsPublic:   isPublic,
		Status:     domain.RoomWaiting,
		Latitude:   in.Latitude,
		Longitude:  in.Longitude,
		MaxPlayers: 4,
	}
	if err := s.roomRepo.Create(ctx, room); err != nil {
		return nil, apierror.Internal()
	}

	// Host takes seat 0
	now := time.Now()
	seat := &domain.RoomSeat{
		RoomID:   room.ID,
		PlayerID: hostID,
		SeatNum:  0,
		JoinedAt: now,
	}
	if err := s.roomRepo.AddSeat(ctx, seat); err != nil {
		return nil, apierror.Internal()
	}

	// Stop host's active broadcast
	s.broadcastSvc.StopActiveForPlayer(ctx, hostID)

	room, _ = s.roomRepo.GetByID(ctx, room.ID)
	go s.notify.NotifyRoomMembers(ctx, room, domain.EventRoomCreated, hostID)
	return room, nil
}

func (s *RoomService) Join(ctx context.Context, userID, roomID string) (*domain.Room, error) {
	room, err := s.roomRepo.GetByID(ctx, roomID)
	if err != nil || room == nil {
		return nil, apierror.NotFound("Room not found")
	}

	if room.Status != domain.RoomWaiting {
		return nil, apierror.BadRequest(apierror.CodeRoomNotJoinable, "Room is not accepting players")
	}

	// Check the player is not already in another room
	if existing, _ := s.roomRepo.GetActiveSeatByPlayerID(ctx, userID); existing != nil {
		if existing.RoomID == roomID {
			return room, nil // already in this room – idempotent
		}
		return nil, apierror.Conflict(apierror.CodeAlreadyInRoom, "You are already in another room")
	}

	// Block check: reject if any current member has blocked this user or vice versa
	for _, seat := range room.Seats {
		if seat.LeftAt != nil {
			continue
		}
		if blocked, _ := s.socialRepo.IsBlocked(ctx, userID, seat.PlayerID); blocked {
			return nil, apierror.Forbidden("Cannot join this room")
		}
	}

	activeSeats, err := s.roomRepo.GetActiveSeatsByRoomID(ctx, roomID)
	if err != nil {
		return nil, apierror.Internal()
	}
	if len(activeSeats) >= room.MaxPlayers {
		return nil, apierror.BadRequest(apierror.CodeRoomFull, "Room is full")
	}

	now := time.Now()
	seat := &domain.RoomSeat{
		RoomID:   roomID,
		PlayerID: userID,
		SeatNum:  len(activeSeats),
		JoinedAt: now,
	}
	if err := s.roomRepo.AddSeat(ctx, seat); err != nil {
		return nil, apierror.Internal()
	}

	// Stop player's broadcast
	s.broadcastSvc.StopActiveForPlayer(ctx, userID)

	room, _ = s.roomRepo.GetByID(ctx, roomID)
	go s.notify.NotifyRoomMembers(ctx, room, domain.EventRoomPlayerJoined, userID)

	// Promote to FULL when all seats are occupied
	updatedSeats, _ := s.roomRepo.GetActiveSeatsByRoomID(ctx, roomID)
	if len(updatedSeats) >= room.MaxPlayers {
		_ = s.roomRepo.UpdateStatus(ctx, roomID, domain.RoomFull)
		room.Status = domain.RoomFull
		go s.notify.NotifyRoomMembers(ctx, room, domain.EventRoomFull, "")
	}

	return room, nil
}

func (s *RoomService) Leave(ctx context.Context, userID, roomID string) error {
	room, err := s.roomRepo.GetByID(ctx, roomID)
	if err != nil || room == nil {
		return apierror.NotFound("Room not found")
	}

	if err := s.roomRepo.LeaveSeat(ctx, roomID, userID); err != nil {
		return apierror.Internal()
	}

	room, _ = s.roomRepo.GetByID(ctx, roomID)
	go s.notify.NotifyRoomMembers(ctx, room, domain.EventRoomPlayerLeft, userID)

	// If the host left, transfer to the next oldest member
	if room.HostID == userID {
		activeSeats, _ := s.roomRepo.GetActiveSeatsByRoomID(ctx, roomID)
		if len(activeSeats) == 0 {
			_ = s.roomRepo.UpdateStatus(ctx, roomID, domain.RoomClosed)
			go s.notify.NotifyRoomMembers(ctx, room, domain.EventRoomDissolved, userID)
		} else {
			newHost := activeSeats[0].PlayerID
			room.HostID = newHost
			_ = s.roomRepo.Update(ctx, room)
		}
	}

	// If the room was FULL and a player left, revert to WAITING
	if room.Status == domain.RoomFull {
		_ = s.roomRepo.UpdateStatus(ctx, roomID, domain.RoomWaiting)
	}

	return nil
}

func (s *RoomService) Dissolve(ctx context.Context, userID, roomID string) error {
	room, err := s.roomRepo.GetByID(ctx, roomID)
	if err != nil || room == nil {
		return apierror.NotFound("Room not found")
	}
	if room.HostID != userID {
		return apierror.Forbidden("Only the host can dissolve the room")
	}
	if room.Status == domain.RoomClosed {
		return nil
	}

	_ = s.roomRepo.UpdateStatus(ctx, roomID, domain.RoomClosed)
	go s.notify.NotifyRoomMembers(ctx, room, domain.EventRoomDissolved, userID)
	return nil
}

func (s *RoomService) GetByID(ctx context.Context, id string) (*domain.Room, error) {
	room, err := s.roomRepo.GetByID(ctx, id)
	if err != nil {
		return nil, apierror.Internal()
	}
	if room == nil {
		return nil, apierror.NotFound("Room not found")
	}
	return room, nil
}

func (s *RoomService) GetMyRoom(ctx context.Context, userID string) (*domain.Room, error) {
	room, err := s.roomRepo.GetActiveRoomByPlayerID(ctx, userID)
	if err != nil {
		return nil, apierror.Internal()
	}
	return room, nil // nil is valid (player not in a room)
}

func (s *RoomService) ListNearby(ctx context.Context) ([]domain.Room, error) {
	rooms, err := s.roomRepo.ListPublicWaiting(ctx)
	if err != nil {
		return nil, apierror.Internal()
	}
	return rooms, nil
}
