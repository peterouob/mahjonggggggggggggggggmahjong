package service

import (
	"context"
	"net/http"

	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/domain"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/repository"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/pkg/apierror"

	"golang.org/x/crypto/bcrypt"
)

type AuthService struct {
	userRepo repository.UserRepo
}

func NewAuthService(userRepo repository.UserRepo) *AuthService {
	return &AuthService{userRepo: userRepo}
}

type RegisterInput struct {
	Username    string `json:"username"    binding:"required,min=3,max=50"`
	Email       string `json:"email"       binding:"required,email"`
	Password    string `json:"password"    binding:"required,min=8"`
	DisplayName string `json:"displayName" binding:"required,min=1,max=100"`
}

type LoginInput struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

func (s *AuthService) Register(ctx context.Context, in RegisterInput) (*domain.User, error) {
	if existing, _ := s.userRepo.GetByUsername(ctx, in.Username); existing != nil {
		return nil, apierror.Conflict(apierror.CodeValidationError, "Username already taken")
	}
	if existing, _ := s.userRepo.GetByEmail(ctx, in.Email); existing != nil {
		return nil, apierror.Conflict(apierror.CodeValidationError, "Email already registered")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, apierror.Internal()
	}

	user := &domain.User{
		Username:     in.Username,
		Email:        in.Email,
		PasswordHash: string(hash),
		DisplayName:  in.DisplayName,
	}
	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, apierror.Internal()
	}
	return user, nil
}

func (s *AuthService) Login(ctx context.Context, in LoginInput) (*domain.User, error) {
	user, err := s.userRepo.GetByUsername(ctx, in.Username)
	if err != nil || user == nil {
		return nil, apierror.New(http.StatusUnauthorized, apierror.CodeInvalidCredentials, "Invalid username or password")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(in.Password)); err != nil {
		return nil, apierror.New(http.StatusUnauthorized, apierror.CodeInvalidCredentials, "Invalid username or password")
	}
	return user, nil
}
