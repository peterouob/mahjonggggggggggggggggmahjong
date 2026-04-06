package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"mahjong/internal/config"

	"github.com/redis/go-redis/v9"
)

const (
	KeyGeoBroadcasts  = "geo:broadcasts"
	KeyGeoOnlineUsers = "geo:online_users"

	ttlBroadcast  = 10 * time.Minute
	ttlFriends    = 10 * time.Minute
	ttlBlocked    = time.Hour
	ttlJWTBlocked = 2 * time.Hour // upper bound; actual value set to token remaining TTL
)

// Redis wraps go-redis and provides helper methods used by services.
type Redis struct {
	client *redis.Client
}

func NewRedis(cfg config.RedisConfig) (*Redis, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.Addr(),
		Password: cfg.Pass,
		DB:       0,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("redis ping: %w", err)
	}

	return &Redis{client: rdb}, nil
}

// Client exposes the raw client for pub/sub and other advanced operations.
func (r *Redis) Client() *redis.Client {
	return r.client
}

// ─── Broadcast Geo ───────────────────────────────────────────────────────────

func (r *Redis) GeoAddBroadcast(ctx context.Context, playerID string, lat, lng float64) error {
	return r.client.GeoAdd(ctx, KeyGeoBroadcasts, &redis.GeoLocation{
		Name:      playerID,
		Latitude:  lat,
		Longitude: lng,
	}).Err()
}

func (r *Redis) GeoRemoveBroadcast(ctx context.Context, playerID string) error {
	return r.client.ZRem(ctx, KeyGeoBroadcasts, playerID).Err()
}

// GeoSearchBroadcasts returns players broadcasting within radiusKm of the given point.
func (r *Redis) GeoSearchBroadcasts(ctx context.Context, lat, lng, radiusKm float64) ([]redis.GeoLocation, error) {
	return r.client.GeoSearchLocation(ctx, KeyGeoBroadcasts, &redis.GeoSearchLocationQuery{
		GeoSearchQuery: redis.GeoSearchQuery{
			Longitude:  lng,
			Latitude:   lat,
			Radius:     radiusKm,
			RadiusUnit: "km",
			Sort:       "ASC",
			Count:      200,
		},
		WithCoord: true,
		WithDist:  true,
	}).Result()
}

// ─── Online Users Geo ─────────────────────────────────────────────────────────

func (r *Redis) GeoAddOnlineUser(ctx context.Context, userID string, lat, lng float64) error {
	return r.client.GeoAdd(ctx, KeyGeoOnlineUsers, &redis.GeoLocation{
		Name:      userID,
		Latitude:  lat,
		Longitude: lng,
	}).Err()
}

func (r *Redis) GeoRemoveOnlineUser(ctx context.Context, userID string) error {
	return r.client.ZRem(ctx, KeyGeoOnlineUsers, userID).Err()
}

// GeoSearchOnlineUsers returns users connected via WebSocket within radiusKm.
func (r *Redis) GeoSearchOnlineUsers(ctx context.Context, lat, lng, radiusKm float64) ([]redis.GeoLocation, error) {
	return r.client.GeoSearchLocation(ctx, KeyGeoOnlineUsers, &redis.GeoSearchLocationQuery{
		GeoSearchQuery: redis.GeoSearchQuery{
			Longitude:  lng,
			Latitude:   lat,
			Radius:     radiusKm,
			RadiusUnit: "km",
			Sort:       "ASC",
			Count:      500,
		},
		WithCoord: true,
		WithDist:  true,
	}).Result()
}

// ─── Broadcast TTL heartbeat ──────────────────────────────────────────────────

func (r *Redis) SetBroadcastTTL(ctx context.Context, playerID string) error {
	key := fmt.Sprintf("broadcast:ttl:%s", playerID)
	return r.client.Set(ctx, key, "1", ttlBroadcast).Err()
}

func (r *Redis) DeleteBroadcastTTL(ctx context.Context, playerID string) error {
	return r.client.Del(ctx, fmt.Sprintf("broadcast:ttl:%s", playerID)).Err()
}

func (r *Redis) BroadcastTTLExists(ctx context.Context, playerID string) (bool, error) {
	n, err := r.client.Exists(ctx, fmt.Sprintf("broadcast:ttl:%s", playerID)).Result()
	return n > 0, err
}

// ─── Friends cache ────────────────────────────────────────────────────────────

func (r *Redis) SetFriendIDs(ctx context.Context, userID string, friendIDs []string) error {
	if len(friendIDs) == 0 {
		return r.client.Del(ctx, fmt.Sprintf("friends:%s", userID)).Err()
	}
	members := make([]interface{}, len(friendIDs))
	for i, id := range friendIDs {
		members[i] = id
	}
	pipe := r.client.Pipeline()
	key := fmt.Sprintf("friends:%s", userID)
	pipe.Del(ctx, key)
	pipe.SAdd(ctx, key, members...)
	pipe.Expire(ctx, key, ttlFriends)
	_, err := pipe.Exec(ctx)
	return err
}

func (r *Redis) GetFriendIDs(ctx context.Context, userID string) ([]string, bool, error) {
	key := fmt.Sprintf("friends:%s", userID)
	exists, err := r.client.Exists(ctx, key).Result()
	if err != nil || exists == 0 {
		return nil, false, err
	}
	ids, err := r.client.SMembers(ctx, key).Result()
	return ids, true, err
}

func (r *Redis) InvalidateFriendCache(ctx context.Context, userID string) error {
	return r.client.Del(ctx, fmt.Sprintf("friends:%s", userID)).Err()
}

// ─── Block cache ──────────────────────────────────────────────────────────────

func (r *Redis) InvalidateBlockCache(ctx context.Context, userID string) error {
	return r.client.Del(ctx, fmt.Sprintf("blocked:%s", userID)).Err()
}

// ─── JWT blacklist ────────────────────────────────────────────────────────────

func (r *Redis) BlacklistJWT(ctx context.Context, jti string, ttl time.Duration) error {
	return r.client.Set(ctx, fmt.Sprintf("jwt:blacklist:%s", jti), "1", ttl).Err()
}

func (r *Redis) IsJWTBlacklisted(ctx context.Context, jti string) (bool, error) {
	n, err := r.client.Exists(ctx, fmt.Sprintf("jwt:blacklist:%s", jti)).Result()
	return n > 0, err
}

// ─── Rate limiting ────────────────────────────────────────────────────────────

// RateLimit implements a fixed-window counter. Returns (allowed, error).
func (r *Redis) RateLimit(ctx context.Context, userID, action string, limit int, window time.Duration) (bool, error) {
	windowKey := time.Now().Unix() / int64(window.Seconds())
	key := fmt.Sprintf("rate:%s:%s:%d", userID, action, windowKey)

	count, err := r.client.Incr(ctx, key).Result()
	if err != nil {
		return true, err // fail open
	}
	if count == 1 {
		r.client.Expire(ctx, key, window*2)
	}
	return count <= int64(limit), nil
}

// ─── Pub/Sub ──────────────────────────────────────────────────────────────────

// UserChannelKey returns the personal pub/sub channel name for a user.
func UserChannelKey(userID string) string {
	return fmt.Sprintf("mahjong:user:%s", userID)
}

// Publish serialises payload as JSON and publishes to a user's personal channel.
func (r *Redis) PublishToUser(ctx context.Context, userID string, payload interface{}) error {
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	return r.client.Publish(ctx, UserChannelKey(userID), data).Err()
}
