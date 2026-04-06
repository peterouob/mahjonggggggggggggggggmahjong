package repository

import (
	"context"

	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/domain"
)

// BroadcastRepo is the interface used by BroadcastService.
// BroadcastRepository (DB-backed) and MockBroadcastRepository both implement it.
type BroadcastRepo interface {
	Create(ctx context.Context, b *domain.Broadcast) error
	GetByID(ctx context.Context, id string) (*domain.Broadcast, error)
	GetActiveByPlayerID(ctx context.Context, playerID string) (*domain.Broadcast, error)
	Update(ctx context.Context, b *domain.Broadcast) error
	Stop(ctx context.Context, id string) error
	StopAllActiveByPlayerID(ctx context.Context, playerID string) error
}
