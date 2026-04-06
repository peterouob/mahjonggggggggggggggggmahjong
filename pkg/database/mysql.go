package database

import (
	"mahjong/internal/config"
	"mahjong/internal/domain"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Connect opens a MySQL connection and runs AutoMigrate for all domain models.
func Connect(cfg config.DatabaseConfig) (*gorm.DB, error) {
	db, err := gorm.Open(mysql.Open(cfg.DSN()), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return nil, err
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}
	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(10)

	if err := migrate(db); err != nil {
		return nil, err
	}

	return db, nil
}

func migrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&domain.User{},
		&domain.Broadcast{},
		&domain.Room{},
		&domain.RoomSeat{},
		&domain.Friendship{},
		&domain.BlockedUser{},
	)
}
