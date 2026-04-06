package service

import (
	"context"

	"mahjong/internal/domain"
	"mahjong/internal/repository"
	"mahjong/pkg/apierror"
	"mahjong/pkg/cache"
)

type SocialService struct {
	socialRepo *repository.SocialRepository
	userRepo   repository.UserRepo
	rdb        *cache.Redis
	notify     *NotificationService
}

func NewSocialService(
	socialRepo *repository.SocialRepository,
	userRepo repository.UserRepo,
	rdb *cache.Redis,
	notify *NotificationService,
) *SocialService {
	return &SocialService{
		socialRepo: socialRepo,
		userRepo:   userRepo,
		rdb:        rdb,
		notify:     notify,
	}
}

func (s *SocialService) SendFriendRequest(ctx context.Context, fromID, toID string) error {
	if fromID == toID {
		return apierror.BadRequest(apierror.CodeValidationError, "Cannot send a friend request to yourself")
	}

	// Account age gate reuses User.CanBroadcast (same 24 h rule)
	user, _ := s.userRepo.GetByID(ctx, fromID)
	if user == nil || !user.CanBroadcast() {
		return apierror.BadRequest(apierror.CodeBroadcastAgeRestricted,
			"New accounts must be at least 24 hours old before sending friend requests")
	}

	target, _ := s.userRepo.GetByID(ctx, toID)
	if target == nil {
		return apierror.NotFound("User not found")
	}

	// Block check
	if blocked, _ := s.socialRepo.IsBlocked(ctx, fromID, toID); blocked {
		return apierror.Forbidden("Cannot send a friend request to this user")
	}

	// Already friends or pending?
	existing, _ := s.socialRepo.GetFriendship(ctx, fromID, toID)
	if existing != nil {
		switch existing.Status {
		case domain.FriendAccepted:
			return apierror.Conflict(apierror.CodeAlreadyFriend, "Already friends")
		case domain.FriendPending:
			return apierror.Conflict(apierror.CodeFriendRequestExists, "Friend request already pending")
		}
	}

	// Friend limit (200 per user)
	count, _ := s.socialRepo.CountFriends(ctx, fromID)
	if count >= maxFriends {
		return apierror.BadRequest(apierror.CodeFriendLimitExceeded, "Friend limit of 200 reached")
	}

	f := &domain.Friendship{
		UserIDA:     fromID,
		UserIDB:     toID,
		Status:      domain.FriendPending,
		InitiatorID: fromID,
	}
	if err := s.socialRepo.CreateFriendship(ctx, f); err != nil {
		return apierror.Internal()
	}

	go s.notify.NotifyUser(ctx, toID, domain.WSEvent{
		Type: domain.EventFriendRequest,
		Data: map[string]string{"fromId": fromID, "requestId": f.ID, "displayName": user.DisplayName},
	})
	return nil
}

func (s *SocialService) AcceptFriendRequest(ctx context.Context, userID, requestID string) error {
	f, err := s.socialRepo.GetFriendshipByID(ctx, requestID)
	if err != nil || f == nil {
		return apierror.NotFound("Friend request not found")
	}
	if f.UserIDA != userID && f.UserIDB != userID {
		return apierror.Forbidden("Not your friend request")
	}
	if f.InitiatorID == userID {
		return apierror.Forbidden("Cannot accept your own request")
	}
	if f.Status != domain.FriendPending {
		return apierror.BadRequest(apierror.CodeValidationError, "Request is not pending")
	}

	f.Status = domain.FriendAccepted
	if err := s.socialRepo.UpdateFriendship(ctx, f); err != nil {
		return apierror.Internal()
	}

	// Invalidate both users' friend caches
	_ = s.rdb.InvalidateFriendCache(ctx, f.UserIDA)
	_ = s.rdb.InvalidateFriendCache(ctx, f.UserIDB)

	go s.notify.NotifyUser(ctx, f.InitiatorID, domain.WSEvent{
		Type: domain.EventFriendAccepted,
		Data: map[string]string{"friendId": userID, "requestId": requestID},
	})
	return nil
}

func (s *SocialService) RejectFriendRequest(ctx context.Context, userID, requestID string) error {
	f, err := s.socialRepo.GetFriendshipByID(ctx, requestID)
	if err != nil || f == nil {
		return apierror.NotFound("Friend request not found")
	}
	if f.UserIDA != userID && f.UserIDB != userID {
		return apierror.Forbidden("Not your friend request")
	}
	if f.InitiatorID == userID {
		return apierror.Forbidden("Cannot reject your own request")
	}
	if f.Status != domain.FriendPending {
		return apierror.BadRequest(apierror.CodeValidationError, "Request is not pending")
	}

	f.Status = domain.FriendRejected
	return s.socialRepo.UpdateFriendship(ctx, f)
}

func (s *SocialService) RemoveFriend(ctx context.Context, userID, friendID string) error {
	f, _ := s.socialRepo.GetFriendship(ctx, userID, friendID)
	if f == nil || f.Status != domain.FriendAccepted {
		return apierror.NotFound("Friendship not found")
	}

	if err := s.socialRepo.DeleteFriendship(ctx, userID, friendID); err != nil {
		return apierror.Internal()
	}

	_ = s.rdb.InvalidateFriendCache(ctx, userID)
	_ = s.rdb.InvalidateFriendCache(ctx, friendID)
	return nil
}

func (s *SocialService) ListFriends(ctx context.Context, userID string) ([]domain.User, error) {
	// Try cache first
	ids, hit, _ := s.rdb.GetFriendIDs(ctx, userID)
	if !hit {
		var err error
		ids, err = s.socialRepo.ListFriendIDs(ctx, userID)
		if err != nil {
			return nil, apierror.Internal()
		}
		_ = s.rdb.SetFriendIDs(ctx, userID, ids)
	}
	if len(ids) == 0 {
		return []domain.User{}, nil
	}

	users, err := s.userRepo.GetByIDs(ctx, ids)
	if err != nil {
		return nil, apierror.Internal()
	}
	return users, nil
}

func (s *SocialService) ListPendingRequests(ctx context.Context, userID string) ([]domain.Friendship, error) {
	fs, err := s.socialRepo.ListPendingRequestsForUser(ctx, userID)
	if err != nil {
		return nil, apierror.Internal()
	}
	return fs, nil
}

func (s *SocialService) BlockUser(ctx context.Context, blockerID, blockedID string) error {
	if blockerID == blockedID {
		return apierror.BadRequest(apierror.CodeValidationError, "Cannot block yourself")
	}

	existing, _ := s.socialRepo.GetBlock(ctx, blockerID, blockedID)
	if existing != nil {
		return apierror.Conflict(apierror.CodeAlreadyBlocked, "Already blocked")
	}

	block := &domain.BlockedUser{
		BlockerID: blockerID,
		BlockedID: blockedID,
	}
	if err := s.socialRepo.BlockUser(ctx, block); err != nil {
		return apierror.Internal()
	}

	// Remove any existing friendship
	_ = s.socialRepo.DeleteFriendship(ctx, blockerID, blockedID)
	_ = s.rdb.InvalidateFriendCache(ctx, blockerID)
	_ = s.rdb.InvalidateFriendCache(ctx, blockedID)
	_ = s.rdb.InvalidateBlockCache(ctx, blockerID)

	return nil
}

func (s *SocialService) UnblockUser(ctx context.Context, blockerID, blockedID string) error {
	if err := s.socialRepo.UnblockUser(ctx, blockerID, blockedID); err != nil {
		return apierror.Internal()
	}
	_ = s.rdb.InvalidateBlockCache(ctx, blockerID)
	return nil
}
