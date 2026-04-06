package repository

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/domain"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/pkg/apierror"
)

// MockRoomRepository is an in-memory RoomRepo for use when MOCK_USERS=true.
type MockRoomRepository struct {
	mu    sync.RWMutex
	rooms map[string]*domain.Room
	seats map[string]*domain.RoomSeat // keyed by seat ID
}

func NewMockRoomRepository() *MockRoomRepository {
	return &MockRoomRepository{
		rooms: make(map[string]*domain.Room),
		seats: make(map[string]*domain.RoomSeat),
	}
}

func (r *MockRoomRepository) Create(_ context.Context, room *domain.Room) error {
	room.ID = uuid.New().String()
	now := time.Now()
	room.CreatedAt = now
	room.UpdatedAt = now
	r.mu.Lock()
	r.rooms[room.ID] = room
	r.mu.Unlock()
	return nil
}

// GetByID returns the room with its active seats and host populated from MockUsers.
func (r *MockRoomRepository) GetByID(_ context.Context, id string) (*domain.Room, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	room, ok := r.rooms[id]
	if !ok {
		return nil, nil
	}
	return r.hydrate(room), nil
}

func (r *MockRoomRepository) Update(_ context.Context, room *domain.Room) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.rooms[room.ID]; !ok {
		return apierror.NotFound("Room not found")
	}
	room.UpdatedAt = time.Now()
	r.rooms[room.ID] = room
	return nil
}

func (r *MockRoomRepository) UpdateStatus(_ context.Context, roomID string, status domain.RoomStatus) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	room, ok := r.rooms[roomID]
	if !ok {
		return apierror.NotFound("Room not found")
	}
	room.Status = status
	room.UpdatedAt = time.Now()
	return nil
}

func (r *MockRoomRepository) AddSeat(_ context.Context, seat *domain.RoomSeat) error {
	seat.ID = uuid.New().String()
	r.mu.Lock()
	r.seats[seat.ID] = seat
	r.mu.Unlock()
	return nil
}

func (r *MockRoomRepository) GetActiveSeatsByRoomID(_ context.Context, roomID string) ([]domain.RoomSeat, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var result []domain.RoomSeat
	for _, s := range r.seats {
		if s.RoomID == roomID && s.LeftAt == nil {
			result = append(result, r.hydrateSeat(s))
		}
	}
	return result, nil
}

func (r *MockRoomRepository) GetActiveSeatByPlayerID(_ context.Context, playerID string) (*domain.RoomSeat, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, s := range r.seats {
		if s.PlayerID == playerID && s.LeftAt == nil {
			hydrated := r.hydrateSeat(s)
			return &hydrated, nil
		}
	}
	return nil, nil
}

func (r *MockRoomRepository) LeaveSeat(_ context.Context, roomID, playerID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	now := time.Now()
	for _, s := range r.seats {
		if s.RoomID == roomID && s.PlayerID == playerID && s.LeftAt == nil {
			s.LeftAt = &now
			return nil
		}
	}
	return nil
}

func (r *MockRoomRepository) ListPublicWaiting(_ context.Context) ([]domain.Room, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var result []domain.Room
	for _, room := range r.rooms {
		if room.IsPublic && room.Status == domain.RoomWaiting {
			result = append(result, *r.hydrate(room))
		}
	}
	return result, nil
}

func (r *MockRoomRepository) GetActiveRoomByPlayerID(ctx context.Context, playerID string) (*domain.Room, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, s := range r.seats {
		if s.PlayerID == playerID && s.LeftAt == nil {
			room, ok := r.rooms[s.RoomID]
			if ok && room.Status != domain.RoomClosed {
				return r.hydrate(room), nil
			}
		}
	}
	return nil, nil
}

// hydrate populates a room's Seats and Host fields from in-memory data.
// Must be called with at least r.mu.RLock held.
func (r *MockRoomRepository) hydrate(room *domain.Room) *domain.Room {
	copy := *room
	copy.Seats = nil
	for _, s := range r.seats {
		if s.RoomID == room.ID && s.LeftAt == nil {
			seat := r.hydrateSeat(s)
			copy.Seats = append(copy.Seats, seat)
		}
	}
	if u, ok := MockUsers[room.HostID]; ok {
		copy.Host = u
	}
	return &copy
}

func (r *MockRoomRepository) hydrateSeat(s *domain.RoomSeat) domain.RoomSeat {
	seat := *s
	if u, ok := MockUsers[s.PlayerID]; ok {
		seat.Player = u
	}
	return seat
}
