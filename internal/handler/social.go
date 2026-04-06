package handler

import (
	"net/http"
	"time"

	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/middleware"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/repository"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/service"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/pkg/apierror"

	"github.com/gin-gonic/gin"
)

type pendingRequestView struct {
	ID              string    `json:"id"`
	FromUserID      string    `json:"fromUserId"`
	FromUsername    string    `json:"fromUsername"`
	FromDisplayName string    `json:"fromDisplayName"`
	CreatedAt       time.Time `json:"createdAt"`
}

type SocialHandler struct {
	socialSvc *service.SocialService
	userRepo  repository.UserRepo
}

func NewSocialHandler(socialSvc *service.SocialService, userRepo repository.UserRepo) *SocialHandler {
	return &SocialHandler{socialSvc: socialSvc, userRepo: userRepo}
}

// GET /api/v1/friends
func (h *SocialHandler) ListFriends(c *gin.Context) {
	userID := middleware.GetUserID(c)

	friends, err := h.socialSvc.ListFriends(c.Request.Context(), userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"friends": friends})
}

// GET /api/v1/friends/requests
// Returns pending requests enriched with sender info.
func (h *SocialHandler) ListPendingRequests(c *gin.Context) {
	userID := middleware.GetUserID(c)

	requests, err := h.socialSvc.ListPendingRequests(c.Request.Context(), userID)
	if err != nil {
		respondError(c, err)
		return
	}

	views := make([]pendingRequestView, 0, len(requests))
	for _, f := range requests {
		sender, _ := h.userRepo.GetByID(c.Request.Context(), f.InitiatorID)
		v := pendingRequestView{
			ID:         f.ID,
			FromUserID: f.InitiatorID,
			CreatedAt:  f.CreatedAt,
		}
		if sender != nil {
			v.FromUsername = sender.Username
			v.FromDisplayName = sender.DisplayName
		}
		views = append(views, v)
	}
	c.JSON(http.StatusOK, gin.H{"requests": views})
}

// POST /api/v1/friends/requests
// Accepts either {"toId": "<uuid>"} or {"toUsername": "<username>"}.
func (h *SocialHandler) SendRequest(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var body struct {
		ToID       string `json:"toId"`
		ToUsername string `json:"toUsername"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		respondError(c, apierror.BadRequest(apierror.CodeValidationError, err.Error()))
		return
	}

	toID := body.ToID
	if toID == "" && body.ToUsername != "" {
		target, err := h.userRepo.GetByUsername(c.Request.Context(), body.ToUsername)
		if err != nil || target == nil {
			respondError(c, apierror.NotFound("User not found"))
			return
		}
		toID = target.ID
	}
	if toID == "" {
		respondError(c, apierror.BadRequest(apierror.CodeValidationError, "toId or toUsername is required"))
		return
	}

	if err := h.socialSvc.SendFriendRequest(c.Request.Context(), userID, toID); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"message": "Friend request sent"})
}

// PUT /api/v1/friends/requests/:id/accept
func (h *SocialHandler) AcceptRequest(c *gin.Context) {
	userID := middleware.GetUserID(c)

	if err := h.socialSvc.AcceptFriendRequest(c.Request.Context(), userID, c.Param("id")); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Friend request accepted"})
}

// PUT /api/v1/friends/requests/:id/reject
func (h *SocialHandler) RejectRequest(c *gin.Context) {
	userID := middleware.GetUserID(c)

	if err := h.socialSvc.RejectFriendRequest(c.Request.Context(), userID, c.Param("id")); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Friend request rejected"})
}

// DELETE /api/v1/friends/:id
func (h *SocialHandler) RemoveFriend(c *gin.Context) {
	userID := middleware.GetUserID(c)

	if err := h.socialSvc.RemoveFriend(c.Request.Context(), userID, c.Param("id")); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Friend removed"})
}

// POST /api/v1/users/:id/block
func (h *SocialHandler) BlockUser(c *gin.Context) {
	userID := middleware.GetUserID(c)

	if err := h.socialSvc.BlockUser(c.Request.Context(), userID, c.Param("id")); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "User blocked"})
}

// DELETE /api/v1/users/:id/block
func (h *SocialHandler) UnblockUser(c *gin.Context) {
	userID := middleware.GetUserID(c)

	if err := h.socialSvc.UnblockUser(c.Request.Context(), userID, c.Param("id")); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "User unblocked"})
}
