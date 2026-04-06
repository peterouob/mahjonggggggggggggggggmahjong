package config

import (
	"fmt"

	"github.com/spf13/viper"
)

type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
}

type ServerConfig struct {
	Port    string
	GinMode string
}

type DatabaseConfig struct {
	Host string
	Port string
	User string
	Pass string
	Name string
}

// DSN returns the MySQL data source name for GORM.
func (d DatabaseConfig) DSN() string {
	return "root:password@tcp(127.0.0.1:3306)/mahjong?charset=utf8mb4&parseTime=True&loc=Local"
}

type RedisConfig struct {
	Host string
	Port string
	Pass string
}

func (r RedisConfig) Addr() string {
	return fmt.Sprintf("%s:%s", r.Host, r.Port)
}

type JWTConfig struct {
	Secret     string
	AccessTTL  int // seconds
	RefreshTTL int // seconds
}

func Load() (*Config, error) {
	viper.AutomaticEnv()

	viper.SetDefault("SERVER_PORT", "8080")
	viper.SetDefault("GIN_MODE", "debug")
	viper.SetDefault("DB_HOST", "localhost")
	viper.SetDefault("DB_PORT", "3306")
	viper.SetDefault("DB_USER", "mahjong")
	viper.SetDefault("DB_NAME", "mahjong")
	viper.SetDefault("REDIS_HOST", "localhost")
	viper.SetDefault("REDIS_PORT", "6379")
	viper.SetDefault("JWT_ACCESS_TTL", 3600)
	viper.SetDefault("JWT_REFRESH_TTL", 604800)

	cfg := &Config{
		Server: ServerConfig{
			Port:    viper.GetString("SERVER_PORT"),
			GinMode: viper.GetString("GIN_MODE"),
		},
		Database: DatabaseConfig{
			Host: viper.GetString("DB_HOST"),
			Port: viper.GetString("DB_PORT"),
			User: viper.GetString("DB_USER"),
			Pass: viper.GetString("DB_PASS"),
			Name: viper.GetString("DB_NAME"),
		},
		Redis: RedisConfig{
			Host: viper.GetString("REDIS_HOST"),
			Port: viper.GetString("REDIS_PORT"),
			Pass: viper.GetString("REDIS_PASS"),
		},
		JWT: JWTConfig{
			Secret:     viper.GetString("JWT_SECRET"),
			AccessTTL:  viper.GetInt("JWT_ACCESS_TTL"),
			RefreshTTL: viper.GetInt("JWT_REFRESH_TTL"),
		},
	}

	if cfg.JWT.Secret == "" {
		cfg.JWT.Secret = "jwt_secret"
	}

	return cfg, nil
}
