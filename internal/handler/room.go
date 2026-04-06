package handler

import (
	"net/http"

	"mahjong/internal/middleware"
	"mahjong/internal/service"
	"mahjong/pkg/apierror"

	"github.com/gin-gonic/gin"
)

type RoomHandler struct {
	roomSvc *service.RoomService
}

func NewRoomHandler(roomSvc *service.RoomService) *RoomHandler {
	return &RoomHandler{roomSvc: roomSvc}
}

// POST /api/v1/rooms
func (h *RoomHandler) Create(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var in service.CreateRoomInput
	if err := c.ShouldBindJSON(&in); err != nil {
		respondError(c, apierror.BadRequest(apierror.CodeValidationError, err.Error()))
		return
	}

	room, err := h.roomSvc.Create(c.Request.Context(), userID, in)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"room": room})
}

// GET /api/v1/rooms
func (h *RoomHandler) List(c *gin.Context) {
	rooms, err := h.roomSvc.ListNearby(c.Request.Context())
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"rooms": rooms})
}

// GET /api/v1/rooms/nearby
func (h *RoomHandler) ListNearby(c *gin.Context) {
	rooms, err := h.roomSvc.ListNearby(c.Request.Context())
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"rooms": rooms})
}

// GET /api/v1/rooms/me
func (h *RoomHandler) GetMine(c *gin.Context) {
	userID := middleware.GetUserID(c)

	room, err := h.roomSvc.GetMyRoom(c.Request.Context(), userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"room": room})
}

// GET /api/v1/rooms/:id
func (h *RoomHandler) GetByID(c *gin.Context) {
	room, err := h.roomSvc.GetByID(c.Request.Context(), c.Param("id"))
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"room": room})
}

// POST /api/v1/rooms/:id/join
func (h *RoomHandler) Join(c *gin.Context) {
	userID := middleware.GetUserID(c)

	room, err := h.roomSvc.Join(c.Request.Context(), userID, c.Param("id"))
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"room": room})
}

// POST /api/v1/rooms/:id/leave
func (h *RoomHandler) Leave(c *gin.Context) {
	userID := middleware.GetUserID(c)

	if err := h.roomSvc.Leave(c.Request.Context(), userID, c.Param("id")); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Left room"})
}

// DELETE /api/v1/rooms/:id
func (h *RoomHandler) Dissolve(c *gin.Context) {
	userID := middleware.GetUserID(c)

	if err := h.roomSvc.Dissolve(c.Request.Context(), userID, c.Param("id")); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Room dissolved"})
}
