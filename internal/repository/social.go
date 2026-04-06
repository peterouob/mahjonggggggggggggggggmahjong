package repository

import (
	"context"
	"errors"
	"mahjong/internal/domain"

	"gorm.io/gorm"
)

type SocialRepository struct {
	db *gorm.DB
}

func NewSocialRepository(db *gorm.DB) *SocialRepository {
	return &SocialRepository{db: db}
}

// normalise ensures userIDA < userIDB for consistent storage.
func normalise(a, b string) (string, string) {
	if a < b {
		return a, b
	}
	return b, a
}

func (r *SocialRepository) CreateFriendship(ctx context.Context, f *domain.Friendship) error {
	f.UserIDA, f.UserIDB = normalise(f.UserIDA, f.UserIDB)
	return r.db.WithContext(ctx).Create(f).Error
}

func (r *SocialRepository) GetFriendship(ctx context.Context, userA, userB string) (*domain.Friendship, error) {
	a, b := normalise(userA, userB)
	var f domain.Friendship
	err := r.db.WithContext(ctx).
		Where("user_id_a = ? AND user_id_b = ?", a, b).
		First(&f).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &f, err
}

func (r *SocialRepository) GetFriendshipByID(ctx context.Context, id string) (*domain.Friendship, error) {
	var f domain.Friendship
	err := r.db.WithContext(ctx).First(&f, "id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &f, err
}

func (r *SocialRepository) UpdateFriendship(ctx context.Context, f *domain.Friendship) error {
	return r.db.WithContext(ctx).Save(f).Error
}

func (r *SocialRepository) DeleteFriendship(ctx context.Context, userA, userB string) error {
	a, b := normalise(userA, userB)
	return r.db.WithContext(ctx).
		Where("user_id_a = ? AND user_id_b = ?", a, b).
		Delete(&domain.Friendship{}).Error
}

// ListFriendIDs returns the IDs of accepted friends for a user.
func (r *SocialRepository) ListFriendIDs(ctx context.Context, userID string) ([]string, error) {
	var friendships []domain.Friendship
	err := r.db.WithContext(ctx).
		Where("(user_id_a = ? OR user_id_b = ?) AND status = ?", userID, userID, domain.FriendAccepted).
		Find(&friendships).Error
	if err != nil {
		return nil, err
	}

	ids := make([]string, 0, len(friendships))
	for _, f := range friendships {
		if f.UserIDA == userID {
			ids = append(ids, f.UserIDB)
		} else {
			ids = append(ids, f.UserIDA)
		}
	}
	return ids, nil
}

// ListPendingRequestsForUser returns friendship records where the user is the recipient.
func (r *SocialRepository) ListPendingRequestsForUser(ctx context.Context, userID string) ([]domain.Friendship, error) {
	var fs []domain.Friendship
	err := r.db.WithContext(ctx).
		Where("(user_id_a = ? OR user_id_b = ?) AND status = ? AND initiator_id != ?",
			userID, userID, domain.FriendPending, userID).
		Find(&fs).Error
	return fs, err
}

// CountFriends returns how many accepted friends a user has.
func (r *SocialRepository) CountFriends(ctx context.Context, userID string) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&domain.Friendship{}).
		Where("(user_id_a = ? OR user_id_b = ?) AND status = ?", userID, userID, domain.FriendAccepted).
		Count(&count).Error
	return count, err
}

// ─── Block ────────────────────────────────────────────────────────────────────

func (r *SocialRepository) BlockUser(ctx context.Context, block *domain.BlockedUser) error {
	return r.db.WithContext(ctx).Create(block).Error
}

func (r *SocialRepository) UnblockUser(ctx context.Context, blockerID, blockedID string) error {
	return r.db.WithContext(ctx).
		Where("blocker_id = ? AND blocked_id = ?", blockerID, blockedID).
		Delete(&domain.BlockedUser{}).Error
}

// IsBlocked returns true if either user has blocked the other.
func (r *SocialRepository) IsBlocked(ctx context.Context, userA, userB string) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&domain.BlockedUser{}).
		Where("(blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)",
			userA, userB, userB, userA).
		Count(&count).Error
	return count > 0, err
}

func (r *SocialRepository) GetBlock(ctx context.Context, blockerID, blockedID string) (*domain.BlockedUser, error) {
	var b domain.BlockedUser
	err := r.db.WithContext(ctx).
		Where("blocker_id = ? AND blocked_id = ?", blockerID, blockedID).
		First(&b).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &b, err
}
