package account

import (
	"context"
	"time"
)

type Account struct {
	ID        int64
	Name      string
	Balance   float64
	UpdatedAt time.Time
}

type Repository interface {
	GetByID(ctx context.Context, id int64) (*Account, error)
}
