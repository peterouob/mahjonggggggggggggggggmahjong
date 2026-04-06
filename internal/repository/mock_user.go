package repository

import (
	"context"
	"time"

	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/domain"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/pkg/apierror"
	"golang.org/x/crypto/bcrypt"
)

// mockPassword is the shared login password for all pre-seeded mock users.
const mockPassword = "mock-password"

// MockUsers is the set of pre-defined test users available when MOCK_USERS=true.
// Send X-User-ID: <uuid> on every protected request, or POST /auth/login with
// username + "mock-password" to exercise the auth flow.
var MockUsers = map[string]*domain.User{
	"66018674-ff04-4d50-b593-f89bc72f3bdb": {ID: "66018674-ff04-4d50-b593-f89bc72f3bdb", Username: "alice", Email: "alice@mock.dev", DisplayName: "Alice Wang", CreatedAt: time.Now().Add(-48 * time.Hour)},
	"a4c45f29-a48f-43e2-b3c5-0bb058d23a94": {ID: "a4c45f29-a48f-43e2-b3c5-0bb058d23a94", Username: "bob", Email: "bob@mock.dev", DisplayName: "Bob Chen", CreatedAt: time.Now().Add(-48 * time.Hour)},
	"68952f04-efd2-4658-8257-baa9937e9b43": {ID: "68952f04-efd2-4658-8257-baa9937e9b43", Username: "charlie", Email: "charlie@mock.dev", DisplayName: "Charlie Liu", CreatedAt: time.Now().Add(-48 * time.Hour)},
	"91e67fab-88c4-4dc7-ab88-5240a35d818d": {ID: "91e67fab-88c4-4dc7-ab88-5240a35d818d", Username: "dave", Email: "dave@mock.dev", DisplayName: "Dave Lee", CreatedAt: time.Now().Add(-48 * time.Hour)},
	"973d0af9-b582-4828-a3e0-26d2f801e55e": {ID: "973d0af9-b582-4828-a3e0-26d2f801e55e", Username: "eve", Email: "eve@mock.dev", DisplayName: "Eve Chen", CreatedAt: time.Now().Add(-48 * time.Hour)},
}

func init() {
	hash, err := bcrypt.GenerateFromPassword([]byte(mockPassword), bcrypt.MinCost)
	if err != nil {
		panic("mock_user: failed to hash mock password: " + err.Error())
	}
	for _, u := range MockUsers {
		u.PasswordHash = string(hash)
	}
}

// MockUserRepository is an in-memory UserRepo backed by MockUsers.
// It satisfies the UserRepo interface and requires no database connection.
type MockUserRepository struct{}

func NewMockUserRepository() *MockUserRepository { return &MockUserRepository{} }

func (r *MockUserRepository) Create(_ context.Context, user *domain.User) error {
	MockUsers[user.ID] = user
	return nil
}

func (r *MockUserRepository) GetByID(_ context.Context, id string) (*domain.User, error) {
	u, ok := MockUsers[id]
	if !ok {
		return nil, nil
	}
	return u, nil
}

func (r *MockUserRepository) GetByUsername(_ context.Context, username string) (*domain.User, error) {
	for _, u := range MockUsers {
		if u.Username == username {
			return u, nil
		}
	}
	return nil, nil
}

func (r *MockUserRepository) GetByEmail(_ context.Context, email string) (*domain.User, error) {
	for _, u := range MockUsers {
		if u.Email == email {
			return u, nil
		}
	}
	return nil, nil
}

func (r *MockUserRepository) GetByIDs(_ context.Context, ids []string) ([]domain.User, error) {
	var result []domain.User
	for _, id := range ids {
		if u, ok := MockUsers[id]; ok {
			result = append(result, *u)
		}
	}
	return result, nil
}

func (r *MockUserRepository) Update(_ context.Context, user *domain.User) error {
	if _, ok := MockUsers[user.ID]; !ok {
		return apierror.NotFound("User not found")
	}
	MockUsers[user.ID] = user
	return nil
}
