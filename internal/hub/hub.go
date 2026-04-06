package hub

import (
	"context"
	"encoding/json"
	"log"
	"strings"
	"sync"
	"time"

	"mahjong/pkg/cache"

	"github.com/gorilla/websocket"
)

const (
	maxMessageSize = 1024
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = 50 * time.Second // must be less than pongWait
	sendBufferSize = 256
)

// Client represents a single connected WebSocket user.
type Client struct {
	hub    *Hub
	userID string
	conn   *websocket.Conn
	send   chan []byte

	// lat/lng are updated when the client sends an update_location message.
	// They are stored in Redis geo:online_users so services can query nearby users.
	lat    float64
	lng    float64
	hasLoc bool
}

// Hub maintains the set of active WebSocket clients and bridges Redis Pub/Sub
// messages to the appropriate connections.
type Hub struct {
	mu      sync.RWMutex
	clients map[string]*Client // userID → Client
	rdb     *cache.Redis

	register   chan *Client
	unregister chan *Client
}

func New(rdb *cache.Redis) *Hub {
	return &Hub{
		clients:    make(map[string]*Client),
		rdb:        rdb,
		register:   make(chan *Client, 16),
		unregister: make(chan *Client, 16),
	}
}

// Run processes register/unregister events and must be called in its own goroutine.
// It also starts the single Redis PSubscribe goroutine that fans out messages.
func (h *Hub) Run(ctx context.Context) {
	go h.subscribeRedis(ctx)

	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.userID] = client
			h.mu.Unlock()
			log.Printf("hub: client registered userID=%s total=%d", client.userID, len(h.clients))

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.userID]; ok {
				delete(h.clients, client.userID)
				close(client.send)
			}
			h.mu.Unlock()
			// Remove from online geo index
			_ = h.rdb.GeoRemoveOnlineUser(ctx, client.userID)
			log.Printf("hub: client unregistered userID=%s total=%d", client.userID, len(h.clients))

		case <-ctx.Done():
			return
		}
	}
}

// subscribeRedis uses a single pattern subscription to receive messages for
// all connected users' personal channels ("mahjong:user:*").
func (h *Hub) subscribeRedis(ctx context.Context) {
	sub := h.rdb.Client().PSubscribe(ctx, "mahjong:user:*")
	defer sub.Close()

	for {
		select {
		case msg, ok := <-sub.Channel():
			if !ok {
				return
			}
			// Channel format: "mahjong:user:{userID}"
			parts := strings.SplitN(msg.Channel, ":", 3)
			if len(parts) != 3 {
				continue
			}
			userID := parts[2]

			h.mu.RLock()
			client, ok := h.clients[userID]
			h.mu.RUnlock()

			if !ok {
				continue
			}
			select {
			case client.send <- []byte(msg.Payload):
			default:
				// Client's send buffer is full; disconnect it.
				h.unregister <- client
			}

		case <-ctx.Done():
			return
		}
	}
}

// ServeClient upgrades the HTTP connection to WebSocket and starts the client
// pumps. Blocks until the connection closes.
func (h *Hub) ServeClient(userID string, conn *websocket.Conn) {
	client := &Client{
		hub:    h,
		userID: userID,
		conn:   conn,
		send:   make(chan []byte, sendBufferSize),
	}
	h.register <- client

	// Start pumps in goroutines; this function returns when readPump exits.
	go client.writePump()
	client.readPump()
}

// ─── Client read pump ─────────────────────────────────────────────────────────

type incomingMsg struct {
	Type string  `json:"type"`
	Lat  float64 `json:"lat"`
	Lng  float64 `json:"lng"`
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(pongWait))
	})

	for {
		_, raw, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("hub: read error userID=%s: %v", c.userID, err)
			}
			break
		}

		var msg incomingMsg
		if err := json.Unmarshal(raw, &msg); err != nil {
			continue
		}

		switch msg.Type {
		case "update_location":
			c.lat = msg.Lat
			c.lng = msg.Lng
			c.hasLoc = true
			// Update geo index so services can find this user for nearby notifications
			_ = c.hub.rdb.GeoAddOnlineUser(context.Background(), c.userID, msg.Lat, msg.Lng)
		case "ping":
			pong, _ := json.Marshal(map[string]string{"type": "pong"})
			select {
			case c.send <- pong:
			default:
			}
		}
	}
}

// ─── Client write pump ────────────────────────────────────────────────────────

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
