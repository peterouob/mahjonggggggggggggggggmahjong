package handler

import (
	"net/http"

	"mahjong/internal/middleware"
	"mahjong/internal/service"
	"mahjong/pkg/apierror"

	"github.com/gin-gonic/gin"
)

type SocialHandler struct {
	socialSvc *service.SocialService
}

func NewSocialHandler(socialSvc *service.SocialService) *SocialHandler {
	return &SocialHandler{socialSvc: socialSvc}
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
func (h *SocialHandler) ListPendingRequests(c *gin.Context) {
	userID := middleware.GetUserID(c)

	requests, err := h.socialSvc.ListPendingRequests(c.Request.Context(), userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"requests": requests})
}

// POST /api/v1/friends/requests
func (h *SocialHandler) SendRequest(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var body struct {
		ToID string `json:"toId" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		respondError(c, apierror.BadRequest(apierror.CodeValidationError, err.Error()))
		return
	}

	if err := h.socialSvc.SendFriendRequest(c.Request.Context(), userID, body.ToID); err != nil {
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
