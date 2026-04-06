package handler

import (
	"net/http"

	"github.com/peterouob/mahjonggggggggggggggggmahjong/internal/service"
	"github.com/peterouob/mahjonggggggggggggggggmahjong/pkg/apierror"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	authSvc *service.AuthService
}

func NewAuthHandler(authSvc *service.AuthService) *AuthHandler {
	return &AuthHandler{authSvc: authSvc}
}

func (h *AuthHandler) Register(c *gin.Context) {
	var in service.RegisterInput
	if err := c.ShouldBindJSON(&in); err != nil {
		respondError(c, apierror.BadRequest(apierror.CodeValidationError, err.Error()))
		return
	}
	user, err := h.authSvc.Register(c.Request.Context(), in)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"user": user})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var in service.LoginInput
	if err := c.ShouldBindJSON(&in); err != nil {
		respondError(c, apierror.BadRequest(apierror.CodeValidationError, err.Error()))
		return
	}
	user, err := h.authSvc.Login(c.Request.Context(), in)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": user})
}

// respondError is a package-level helper used by all handlers.
func respondError(c *gin.Context, err error) {
	if apiErr, ok := err.(*apierror.APIError); ok {
		c.JSON(apiErr.Status, gin.H{"error": apiErr})
		return
	}
	c.JSON(500, gin.H{"error": gin.H{"code": "INTERNAL_ERROR", "message": "Internal server error"}})
}
