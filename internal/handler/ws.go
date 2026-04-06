package handler

import (
	"net/http"

	"mahjong/internal/hub"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool { return true },
}

type WSHandler struct {
	hub *hub.Hub
}

func NewWSHandler(h *hub.Hub) *WSHandler {
	return &WSHandler{hub: h}
}

// GET /ws?user_id=<uuid>
//
// user_id is sent as a query parameter because the browser WebSocket API
// does not support custom headers on the HTTP upgrade request.
func (h *WSHandler) ServeWS(c *gin.Context) {
	userID := c.Query("user_id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": gin.H{
			"code":    "MISSING_USER_ID",
			"message": "user_id query parameter is required",
		}})
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}

	h.hub.ServeClient(userID, conn)
}
