package service

import (
	"context"
	"log"

	"mahjong/internal/domain"
	"mahjong/pkg/cache"
)

// NotificationService handles routing events to connected WebSocket clients
// via Redis Pub/Sub. FCM push is stubbed — replace fcmPush with a real
// firebase-admin-go call when ready.
type NotificationService struct {
	rdb *cache.Redis
}

func NewNotificationService(rdb *cache.Redis) *NotificationService {
	return &NotificationService{rdb: rdb}
}

// NotifyNearbyBroadcastStarted finds online users within 5 km and delivers
// a broadcast.started event to each of them.
func (n *NotificationService) NotifyNearbyBroadcastStarted(ctx context.Context, b *domain.Broadcast) {
	n.notifyNearbyBroadcastEvent(ctx, b, domain.EventBroadcastStarted)
}

func (n *NotificationService) NotifyNearbyBroadcastUpdated(ctx context.Context, b *domain.Broadcast) {
	n.notifyNearbyBroadcastEvent(ctx, b, domain.EventBroadcastUpdated)
}

func (n *NotificationService) NotifyNearbyBroadcastStopped(ctx context.Context, b *domain.Broadcast) {
	n.notifyNearbyBroadcastEvent(ctx, b, domain.EventBroadcastStopped)
}

func (n *NotificationService) notifyNearbyBroadcastEvent(ctx context.Context, b *domain.Broadcast, eventType domain.EventType) {
	if b.Player == nil {
		return
	}

	nearby, err := n.rdb.GeoSearchOnlineUsers(ctx, b.Latitude, b.Longitude, 5)
	if err != nil {
		log.Printf("NotificationService: GeoSearchOnlineUsers error: %v", err)
		return
	}

	for _, loc := range nearby {
		if loc.Name == b.PlayerID {
			continue // don't echo back to the broadcaster
		}

		event := domain.WSEvent{
			Type: eventType,
			Data: domain.BroadcastEventData{
				BroadcastID:    b.ID,
				PlayerID:       b.PlayerID,
				DisplayName:    b.Player.DisplayName,
				AvatarURL:      b.Player.AvatarURL,
				Latitude:       b.Latitude,
				Longitude:      b.Longitude,
				Message:        b.Message,
				DistanceMeters: loc.Dist * 1000, // GeoSearch returns km
			},
		}

		if err := n.rdb.PublishToUser(ctx, loc.Name, event); err != nil {
			log.Printf("NotificationService: publish to %s failed: %v", loc.Name, err)
		}
	}
}

// NotifyRoomMembers sends a room event to every current seat holder.
func (n *NotificationService) NotifyRoomMembers(ctx context.Context, room *domain.Room, eventType domain.EventType, affectedPlayerID string) {
	data := domain.RoomEventData{
		RoomID:           room.ID,
		EventType:        eventType,
		AffectedPlayerID: affectedPlayerID,
		Room:             room,
	}
	event := domain.WSEvent{Type: eventType, Data: data}

	for _, seat := range room.Seats {
		if seat.LeftAt != nil {
			continue
		}
		if err := n.rdb.PublishToUser(ctx, seat.PlayerID, event); err != nil {
			log.Printf("NotificationService: notify room member %s: %v", seat.PlayerID, err)
		}
	}
}

// NotifyUser delivers an arbitrary event to a single user's channel.
func (n *NotificationService) NotifyUser(ctx context.Context, userID string, event domain.WSEvent) {
	if err := n.rdb.PublishToUser(ctx, userID, event); err != nil {
		log.Printf("NotificationService: notify user %s: %v", userID, err)
	}
}

// fcmPush is a stub. Replace with actual FCM logic using firebase-admin-go.
func fcmPush(token, title, body string) {
	log.Printf("[FCM-STUB] token=%s title=%q body=%q", token, title, body)
}
