package repository

import (
	"context"
	"errors"
	"mahjong/internal/domain"

	"gorm.io/gorm"
)

type BroadcastRepository struct {
	db *gorm.DB
}

func NewBroadcastRepository(db *gorm.DB) *BroadcastRepository {
	return &BroadcastRepository{db: db}
}

func (r *BroadcastRepository) Create(ctx context.Context, b *domain.Broadcast) error {
	return r.db.WithContext(ctx).Create(b).Error
}

func (r *BroadcastRepository) GetByID(ctx context.Context, id string) (*domain.Broadcast, error) {
	var b domain.Broadcast
	err := r.db.WithContext(ctx).Preload("Player").First(&b, "id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &b, err
}

// GetActiveByPlayerID returns the single ACTIVE broadcast for a player, or nil.
func (r *BroadcastRepository) GetActiveByPlayerID(ctx context.Context, playerID string) (*domain.Broadcast, error) {
	var b domain.Broadcast
	err := r.db.WithContext(ctx).
		Where("player_id = ? AND status = ?", playerID, domain.BroadcastActive).
		First(&b).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &b, err
}

func (r *BroadcastRepository) Update(ctx context.Context, b *domain.Broadcast) error {
	return r.db.WithContext(ctx).Save(b).Error
}

// Stop marks a broadcast as STOPPED without loading the full record first.
func (r *BroadcastRepository) Stop(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).
		Model(&domain.Broadcast{}).
		Where("id = ?", id).
		Update("status", domain.BroadcastStopped).Error
}

// StopAllActiveByPlayerID is used when a player joins a room or is blocked.
func (r *BroadcastRepository) StopAllActiveByPlayerID(ctx context.Context, playerID string) error {
	return r.db.WithContext(ctx).
		Model(&domain.Broadcast{}).
		Where("player_id = ? AND status = ?", playerID, domain.BroadcastActive).
		Update("status", domain.BroadcastStopped).Error
}
