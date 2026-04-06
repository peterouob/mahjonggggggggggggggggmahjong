package repository

import (
	"context"

	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/domain"
)

// RoomRepo is the interface used by RoomService.
// RoomRepository (DB-backed) and MockRoomRepository both implement it.
type RoomRepo interface {
	Create(ctx context.Context, room *domain.Room) error
	GetByID(ctx context.Context, id string) (*domain.Room, error)
	Update(ctx context.Context, room *domain.Room) error
	UpdateStatus(ctx context.Context, roomID string, status domain.RoomStatus) error
	AddSeat(ctx context.Context, seat *domain.RoomSeat) error
	GetActiveSeatsByRoomID(ctx context.Context, roomID string) ([]domain.RoomSeat, error)
	GetActiveSeatByPlayerID(ctx context.Context, playerID string) (*domain.RoomSeat, error)
	LeaveSeat(ctx context.Context, roomID, playerID string) error
	ListPublicWaiting(ctx context.Context) ([]domain.Room, error)
	GetActiveRoomByPlayerID(ctx context.Context, playerID string) (*domain.Room, error)
}
