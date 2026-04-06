package repository

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/domain"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/pkg/apierror"
)

// MockSocialRepository is an in-memory SocialRepo for use when MOCK_USERS=true.
type MockSocialRepository struct {
	mu          sync.RWMutex
	friendships map[string]*domain.Friendship  // keyed by friendship ID
	blocks      map[string]*domain.BlockedUser // keyed by block ID
}

func NewMockSocialRepository() *MockSocialRepository {
	return &MockSocialRepository{
		friendships: make(map[string]*domain.Friendship),
		blocks:      make(map[string]*domain.BlockedUser),
	}
}

func mockNormalise(a, b string) (string, string) {
	if a < b {
		return a, b
	}
	return b, a
}

func (r *MockSocialRepository) CreateFriendship(_ context.Context, f *domain.Friendship) error {
	f.UserIDA, f.UserIDB = mockNormalise(f.UserIDA, f.UserIDB)
	f.ID = uuid.New().String()
	now := time.Now()
	f.CreatedAt = now
	f.UpdatedAt = now
	r.mu.Lock()
	r.friendships[f.ID] = f
	r.mu.Unlock()
	return nil
}

func (r *MockSocialRepository) GetFriendship(_ context.Context, userA, userB string) (*domain.Friendship, error) {
	a, b := mockNormalise(userA, userB)
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, f := range r.friendships {
		if f.UserIDA == a && f.UserIDB == b {
			return f, nil
		}
	}
	return nil, nil
}

func (r *MockSocialRepository) GetFriendshipByID(_ context.Context, id string) (*domain.Friendship, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	f, ok := r.friendships[id]
	if !ok {
		return nil, nil
	}
	return f, nil
}

func (r *MockSocialRepository) UpdateFriendship(_ context.Context, f *domain.Friendship) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.friendships[f.ID]; !ok {
		return apierror.NotFound("Friendship not found")
	}
	f.UpdatedAt = time.Now()
	r.friendships[f.ID] = f
	return nil
}

func (r *MockSocialRepository) DeleteFriendship(_ context.Context, userA, userB string) error {
	a, b := mockNormalise(userA, userB)
	r.mu.Lock()
	defer r.mu.Unlock()
	for id, f := range r.friendships {
		if f.UserIDA == a && f.UserIDB == b {
			delete(r.friendships, id)
			return nil
		}
	}
	return nil
}

func (r *MockSocialRepository) ListFriendIDs(_ context.Context, userID string) ([]string, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var ids []string
	for _, f := range r.friendships {
		if f.Status != domain.FriendAccepted {
			continue
		}
		if f.UserIDA == userID {
			ids = append(ids, f.UserIDB)
		} else if f.UserIDB == userID {
			ids = append(ids, f.UserIDA)
		}
	}
	return ids, nil
}

func (r *MockSocialRepository) ListPendingRequestsForUser(_ context.Context, userID string) ([]domain.Friendship, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var result []domain.Friendship
	for _, f := range r.friendships {
		if f.Status == domain.FriendPending && f.InitiatorID != userID &&
			(f.UserIDA == userID || f.UserIDB == userID) {
			result = append(result, *f)
		}
	}
	return result, nil
}

func (r *MockSocialRepository) CountFriends(_ context.Context, userID string) (int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var count int64
	for _, f := range r.friendships {
		if f.Status == domain.FriendAccepted && (f.UserIDA == userID || f.UserIDB == userID) {
			count++
		}
	}
	return count, nil
}

func (r *MockSocialRepository) BlockUser(_ context.Context, block *domain.BlockedUser) error {
	block.ID = uuid.New().String()
	block.CreatedAt = time.Now()
	r.mu.Lock()
	r.blocks[block.ID] = block
	r.mu.Unlock()
	return nil
}

func (r *MockSocialRepository) UnblockUser(_ context.Context, blockerID, blockedID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	for id, b := range r.blocks {
		if b.BlockerID == blockerID && b.BlockedID == blockedID {
			delete(r.blocks, id)
			return nil
		}
	}
	return nil
}

func (r *MockSocialRepository) IsBlocked(_ context.Context, userA, userB string) (bool, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, b := range r.blocks {
		if (b.BlockerID == userA && b.BlockedID == userB) ||
			(b.BlockerID == userB && b.BlockedID == userA) {
			return true, nil
		}
	}
	return false, nil
}

func (r *MockSocialRepository) GetBlock(_ context.Context, blockerID, blockedID string) (*domain.BlockedUser, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, b := range r.blocks {
		if b.BlockerID == blockerID && b.BlockedID == blockedID {
			return b, nil
		}
	}
	return nil, nil
}
