package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ─── User ───────────────────────────────────────────────────────────────────

type User struct {
	ID           string    `gorm:"type:varchar(36);primaryKey"         json:"id"`
	Username     string    `gorm:"type:varchar(50);uniqueIndex;not null" json:"username"`
	Email        string    `gorm:"type:varchar(255);uniqueIndex;not null" json:"email"`
	PasswordHash string    `gorm:"type:varchar(255);not null"           json:"-"`
	DisplayName  string    `gorm:"type:varchar(100);not null"           json:"displayName"`
	AvatarURL    string    `gorm:"type:varchar(500)"                    json:"avatarUrl"`
	CreatedAt    time.Time `                                            json:"createdAt"`
	UpdatedAt    time.Time `                                            json:"updatedAt"`
}

func (u *User) BeforeCreate(_ *gorm.DB) error {
	u.ID = uuid.New().String()
	return nil
}

// CanBroadcast returns true for all accounts (24h restriction disabled for testing).
func (u *User) CanBroadcast() bool {
	return true
}

// ─── Broadcast ───────────────────────────────────────────────────────────────

type BroadcastStatus string

const (
	BroadcastActive  BroadcastStatus = "ACTIVE"
	BroadcastStopped BroadcastStatus = "STOPPED"
)

type Broadcast struct {
	ID        string          `gorm:"type:varchar(36);primaryKey"              json:"id"`
	PlayerID  string          `gorm:"type:varchar(36);not null;index"          json:"playerId"`
	Latitude  float64         `gorm:"not null"                                 json:"latitude"`
	Longitude float64         `gorm:"not null"                                 json:"longitude"`
	Status    BroadcastStatus `gorm:"type:varchar(20);not null;default:ACTIVE" json:"status"`
	Message   string          `gorm:"type:varchar(200)"                        json:"message"`
	ExpiresAt time.Time       `                                                json:"expiresAt"`
	CreatedAt time.Time       `                                                json:"createdAt"`
	UpdatedAt time.Time       `                                                json:"updatedAt"`
	Player    *User           `gorm:"foreignKey:PlayerID"                      json:"player,omitempty"`
}

func (b *Broadcast) BeforeCreate(_ *gorm.DB) error {
	b.ID = uuid.New().String()
	return nil
}

// ─── Room ────────────────────────────────────────────────────────────────────

type RoomStatus string

const (
	RoomWaiting RoomStatus = "WAITING"
	RoomFull    RoomStatus = "FULL"
	RoomPlaying RoomStatus = "PLAYING"
	RoomClosed  RoomStatus = "CLOSED"
)

type GameRule string

const (
	GameRuleTaiwan      GameRule = "TAIWAN_MAHJONG"
	GameRuleThreePlayer GameRule = "THREE_PLAYER"
	GameRuleNational    GameRule = "NATIONAL_STANDARD"
)

type Room struct {
	ID         string     `gorm:"type:varchar(36);primaryKey"                    json:"id"`
	HostID     string     `gorm:"type:varchar(36);not null;index"                json:"hostId"`
	Name       string     `gorm:"type:varchar(100);not null"                     json:"name"`
	PlaceName  string     `gorm:"type:varchar(100)"                              json:"placeName"`
	GameRule   GameRule   `gorm:"type:varchar(30);not null;default:TAIWAN_MAHJONG" json:"gameRule"`
	IsPublic   bool       `gorm:"not null;default:true"                          json:"isPublic"`
	Status     RoomStatus `gorm:"type:varchar(20);not null;default:WAITING"      json:"status"`
	Latitude   float64    `                                                      json:"latitude"`
	Longitude  float64    `                                                      json:"longitude"`
	MaxPlayers int        `gorm:"not null;default:4"                             json:"maxPlayers"`
	CreatedAt  time.Time  `                                                      json:"createdAt"`
	UpdatedAt  time.Time  `                                                      json:"updatedAt"`
	Seats      []RoomSeat `gorm:"foreignKey:RoomID"                              json:"seats,omitempty"`
	Host       *User      `gorm:"foreignKey:HostID"                              json:"host,omitempty"`
}

func (r *Room) BeforeCreate(_ *gorm.DB) error {
	r.ID = uuid.New().String()
	return nil
}

// ActiveSeatCount returns how many seats are currently occupied.
func (r *Room) ActiveSeatCount() int {
	count := 0
	for _, s := range r.Seats {
		if s.LeftAt == nil {
			count++
		}
	}
	return count
}

type RoomSeat struct {
	ID       string     `gorm:"type:varchar(36);primaryKey"         json:"id"`
	RoomID   string     `gorm:"type:varchar(36);not null;index"     json:"roomId"`
	PlayerID string     `gorm:"type:varchar(36);not null;index"     json:"playerId"`
	SeatNum  int        `gorm:"not null"                            json:"seatNum"`
	JoinedAt time.Time  `                                           json:"joinedAt"`
	LeftAt   *time.Time `                                           json:"leftAt"`
	Player   *User      `gorm:"foreignKey:PlayerID"                 json:"player,omitempty"`
}

func (rs *RoomSeat) BeforeCreate(_ *gorm.DB) error {
	rs.ID = uuid.New().String()
	return nil
}

// ─── Social ──────────────────────────────────────────────────────────────────

type FriendshipStatus string

const (
	FriendPending  FriendshipStatus = "PENDING"
	FriendAccepted FriendshipStatus = "ACCEPTED"
	FriendRejected FriendshipStatus = "REJECTED"
)

// Friendship stores a bidirectional friend relation normalised so that
// UserIDA < UserIDB (lexicographic). InitiatorID records who sent the request.
type Friendship struct {
	ID          string           `gorm:"type:varchar(36);primaryKey"         json:"id"`
	UserIDA     string           `gorm:"type:varchar(36);not null;index"     json:"userIdA"`
	UserIDB     string           `gorm:"type:varchar(36);not null;index"     json:"userIdB"`
	Status      FriendshipStatus `gorm:"type:varchar(20);not null"           json:"status"`
	InitiatorID string           `gorm:"type:varchar(36);not null"           json:"initiatorId"`
	CreatedAt   time.Time        `                                           json:"createdAt"`
	UpdatedAt   time.Time        `                                           json:"updatedAt"`
}

func (f *Friendship) BeforeCreate(_ *gorm.DB) error {
	f.ID = uuid.New().String()
	return nil
}

type BlockedUser struct {
	ID        string    `gorm:"type:varchar(36);primaryKey"     json:"id"`
	BlockerID string    `gorm:"type:varchar(36);not null;index" json:"blockerId"`
	BlockedID string    `gorm:"type:varchar(36);not null;index" json:"blockedId"`
	CreatedAt time.Time `                                       json:"createdAt"`
}

func (b *BlockedUser) BeforeCreate(_ *gorm.DB) error {
	b.ID = uuid.New().String()
	return nil
}

// ─── WebSocket / Pub-Sub Events ──────────────────────────────────────────────

type EventType string

const (
	EventBroadcastStarted EventType = "broadcast.started"
	EventBroadcastUpdated EventType = "broadcast.updated"
	EventBroadcastStopped EventType = "broadcast.stopped"
	EventRoomCreated      EventType = "room.created"
	EventRoomPlayerJoined EventType = "room.player_joined"
	EventRoomPlayerLeft   EventType = "room.player_left"
	EventRoomFull         EventType = "room.full"
	EventRoomDissolved    EventType = "room.dissolved"
	EventFriendRequest    EventType = "friend.request"
	EventFriendAccepted   EventType = "friend.accepted"
	EventNotification     EventType = "notification"
)

type WSEvent struct {
	Type EventType   `json:"type"`
	Data interface{} `json:"data"`
}

// BroadcastEventData is the payload for broadcast.* events.
type BroadcastEventData struct {
	BroadcastID    string  `json:"broadcastId"`
	PlayerID       string  `json:"playerId"`
	DisplayName    string  `json:"displayName"`
	AvatarURL      string  `json:"avatarUrl"`
	Latitude       float64 `json:"latitude"`
	Longitude      float64 `json:"longitude"`
	Message        string  `json:"message"`
	DistanceMeters float64 `json:"distanceMeters"`
}

// RoomEventData is the payload for room.* events.
type RoomEventData struct {
	RoomID          string     `json:"roomId"`
	EventType       EventType  `json:"eventType"`
	AffectedPlayerID string    `json:"affectedPlayerId,omitempty"`
	Room            *Room      `json:"room,omitempty"`
}
