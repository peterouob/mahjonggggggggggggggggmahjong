package repository

import (
	"context"
	"errors"
	"mahjong/internal/domain"

	"gorm.io/gorm"
)

type RoomRepository struct {
	db *gorm.DB
}

func NewRoomRepository(db *gorm.DB) *RoomRepository {
	return &RoomRepository{db: db}
}

func (r *RoomRepository) Create(ctx context.Context, room *domain.Room) error {
	return r.db.WithContext(ctx).Create(room).Error
}

func (r *RoomRepository) GetByID(ctx context.Context, id string) (*domain.Room, error) {
	var room domain.Room
	err := r.db.WithContext(ctx).
		Preload("Seats.Player").
		Preload("Host").
		First(&room, "id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &room, err
}

func (r *RoomRepository) Update(ctx context.Context, room *domain.Room) error {
	return r.db.WithContext(ctx).Save(room).Error
}

func (r *RoomRepository) UpdateStatus(ctx context.Context, roomID string, status domain.RoomStatus) error {
	return r.db.WithContext(ctx).
		Model(&domain.Room{}).
		Where("id = ?", roomID).
		Update("status", status).Error
}

// AddSeat inserts a new seat record inside a transaction.
func (r *RoomRepository) AddSeat(ctx context.Context, seat *domain.RoomSeat) error {
	return r.db.WithContext(ctx).Create(seat).Error
}

// GetActiveSeatsByRoomID returns seats where the player has not yet left.
func (r *RoomRepository) GetActiveSeatsByRoomID(ctx context.Context, roomID string) ([]domain.RoomSeat, error) {
	var seats []domain.RoomSeat
	err := r.db.WithContext(ctx).
		Preload("Player").
		Where("room_id = ? AND left_at IS NULL", roomID).
		Order("joined_at ASC").
		Find(&seats).Error
	return seats, err
}

// GetActiveSeatByPlayerID finds the active (not yet left) seat for a player across all rooms.
func (r *RoomRepository) GetActiveSeatByPlayerID(ctx context.Context, playerID string) (*domain.RoomSeat, error) {
	var seat domain.RoomSeat
	err := r.db.WithContext(ctx).
		Where("player_id = ? AND left_at IS NULL", playerID).
		First(&seat).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &seat, err
}

// LeaveSeat soft-deletes a seat by setting left_at to now.
func (r *RoomRepository) LeaveSeat(ctx context.Context, roomID, playerID string) error {
	return r.db.WithContext(ctx).
		Model(&domain.RoomSeat{}).
		Where("room_id = ? AND player_id = ? AND left_at IS NULL", roomID, playerID).
		Update("left_at", gorm.Expr("NOW()")).Error
}

// ListPublicWaiting returns rooms that are public and in WAITING state.
func (r *RoomRepository) ListPublicWaiting(ctx context.Context) ([]domain.Room, error) {
	var rooms []domain.Room
	err := r.db.WithContext(ctx).
		Preload("Seats.Player").
		Preload("Host").
		Where("is_public = true AND status = ?", domain.RoomWaiting).
		Order("created_at DESC").
		Limit(50).
		Find(&rooms).Error
	return rooms, err
}

// GetActiveRoomByPlayerID returns the room a player is currently in, or nil.
func (r *RoomRepository) GetActiveRoomByPlayerID(ctx context.Context, playerID string) (*domain.Room, error) {
	var seat domain.RoomSeat
	err := r.db.WithContext(ctx).
		Where("player_id = ? AND left_at IS NULL", playerID).
		First(&seat).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return r.GetByID(ctx, seat.RoomID)
}
