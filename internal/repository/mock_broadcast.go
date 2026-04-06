package repository

import (
	"context"
	"sync"

	"github.com/google/uuid"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/domain"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/pkg/apierror"
)

// MockBroadcastRepository is an in-memory BroadcastRepo for use when MOCK_USERS=true.
type MockBroadcastRepository struct {
	mu         sync.RWMutex
	broadcasts map[string]*domain.Broadcast
}

func NewMockBroadcastRepository() *MockBroadcastRepository {
	return &MockBroadcastRepository{broadcasts: make(map[string]*domain.Broadcast)}
}

func (r *MockBroadcastRepository) Create(_ context.Context, b *domain.Broadcast) error {
	b.ID = uuid.New().String()
	r.mu.Lock()
	r.broadcasts[b.ID] = b
	r.mu.Unlock()
	return nil
}

func (r *MockBroadcastRepository) GetByID(_ context.Context, id string) (*domain.Broadcast, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	b, ok := r.broadcasts[id]
	if !ok {
		return nil, nil
	}
	return b, nil
}

func (r *MockBroadcastRepository) GetActiveByPlayerID(_ context.Context, playerID string) (*domain.Broadcast, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, b := range r.broadcasts {
		if b.PlayerID == playerID && b.Status == domain.BroadcastActive {
			return b, nil
		}
	}
	return nil, nil
}

func (r *MockBroadcastRepository) Update(_ context.Context, b *domain.Broadcast) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.broadcasts[b.ID]; !ok {
		return apierror.NotFound("Broadcast not found")
	}
	r.broadcasts[b.ID] = b
	return nil
}

func (r *MockBroadcastRepository) Stop(_ context.Context, id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	b, ok := r.broadcasts[id]
	if !ok {
		return apierror.NotFound("Broadcast not found")
	}
	b.Status = domain.BroadcastStopped
	return nil
}

func (r *MockBroadcastRepository) StopAllActiveByPlayerID(_ context.Context, playerID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, b := range r.broadcasts {
		if b.PlayerID == playerID && b.Status == domain.BroadcastActive {
			b.Status = domain.BroadcastStopped
		}
	}
	return nil
}
