package repository

import (
	"context"

	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/domain"
)

// SocialRepo is the interface used by RoomService and SocialService.
// SocialRepository (DB-backed) and MockSocialRepository both implement it.
type SocialRepo interface {
	CreateFriendship(ctx context.Context, f *domain.Friendship) error
	GetFriendship(ctx context.Context, userA, userB string) (*domain.Friendship, error)
	GetFriendshipByID(ctx context.Context, id string) (*domain.Friendship, error)
	UpdateFriendship(ctx context.Context, f *domain.Friendship) error
	DeleteFriendship(ctx context.Context, userA, userB string) error
	ListFriendIDs(ctx context.Context, userID string) ([]string, error)
	ListPendingRequestsForUser(ctx context.Context, userID string) ([]domain.Friendship, error)
	CountFriends(ctx context.Context, userID string) (int64, error)
	BlockUser(ctx context.Context, block *domain.BlockedUser) error
	UnblockUser(ctx context.Context, blockerID, blockedID string) error
	IsBlocked(ctx context.Context, userA, userB string) (bool, error)
	GetBlock(ctx context.Context, blockerID, blockedID string) (*domain.BlockedUser, error)
}
