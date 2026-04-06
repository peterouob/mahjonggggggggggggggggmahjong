package repository

import (
	"context"

	"mahjong/internal/domain"
)

// UserRepo is the interface used by all services that need user data.
// Both UserRepository (DB-backed) and MockUserRepository implement it.
type UserRepo interface {
	Create(ctx context.Context, user *domain.User) error
	GetByID(ctx context.Context, id string) (*domain.User, error)
	GetByUsername(ctx context.Context, username string) (*domain.User, error)
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	GetByIDs(ctx context.Context, ids []string) ([]domain.User, error)
	Update(ctx context.Context, user *domain.User) error
}
