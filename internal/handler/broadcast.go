package handler

import (
	"net/http"
	"strconv"

	"mahjong/internal/middleware"
	"mahjong/internal/service"
	"mahjong/pkg/apierror"

	"github.com/gin-gonic/gin"
)

type BroadcastHandler struct {
	broadcastSvc *service.BroadcastService
}

func NewBroadcastHandler(broadcastSvc *service.BroadcastService) *BroadcastHandler {
	return &BroadcastHandler{broadcastSvc: broadcastSvc}
}

// POST /api/v1/broadcasts
func (h *BroadcastHandler) Start(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var in service.StartBroadcastInput
	if err := c.ShouldBindJSON(&in); err != nil {
		respondError(c, apierror.BadRequest(apierror.CodeValidationError, err.Error()))
		return
	}

	b, err := h.broadcastSvc.Start(c.Request.Context(), userID, in)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"broadcast": b})
}

// PATCH /api/v1/broadcasts/:id/location
func (h *BroadcastHandler) UpdateLocation(c *gin.Context) {
	userID := middleware.GetUserID(c)
	broadcastID := c.Param("id")

	var in service.UpdateLocationInput
	if err := c.ShouldBindJSON(&in); err != nil {
		respondError(c, apierror.BadRequest(apierror.CodeValidationError, err.Error()))
		return
	}

	if err := h.broadcastSvc.UpdateLocation(c.Request.Context(), userID, broadcastID, in); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Location updated"})
}

// DELETE /api/v1/broadcasts/:id
func (h *BroadcastHandler) Stop(c *gin.Context) {
	userID := middleware.GetUserID(c)
	broadcastID := c.Param("id")

	if err := h.broadcastSvc.Stop(c.Request.Context(), userID, broadcastID); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Broadcast stopped"})
}

// POST /api/v1/broadcasts/:id/heartbeat
func (h *BroadcastHandler) Heartbeat(c *gin.Context) {
	userID := middleware.GetUserID(c)
	broadcastID := c.Param("id")

	if err := h.broadcastSvc.Heartbeat(c.Request.Context(), userID, broadcastID); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "ok"})
}

// GET /api/v1/broadcasts/nearby?lat=&lng=&radius_km=
func (h *BroadcastHandler) GetNearby(c *gin.Context) {
	userID := middleware.GetUserID(c)

	lat, err1 := strconv.ParseFloat(c.Query("lat"), 64)
	lng, err2 := strconv.ParseFloat(c.Query("lng"), 64)
	if err1 != nil || err2 != nil {
		respondError(c, apierror.BadRequest(apierror.CodeValidationError, "lat and lng query params are required"))
		return
	}

	radiusKm := 5.0
	if r := c.Query("radius_km"); r != "" {
		if parsed, err := strconv.ParseFloat(r, 64); err == nil {
			radiusKm = parsed
		}
	}

	results, err := h.broadcastSvc.GetNearby(c.Request.Context(), userID, lat, lng, radiusKm)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"broadcasts": results})
}

// GET /api/v1/broadcasts/me
func (h *BroadcastHandler) GetMine(c *gin.Context) {
	userID := middleware.GetUserID(c)

	b, err := h.broadcastSvc.GetMyActive(c.Request.Context(), userID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"broadcast": b})
}
