package transaction

import (
	"context"
	"time"
)

type Status string

const (
	StatusPending   Status = "pending"
	StatusCompleted Status = "completed"
	StatusFailed    Status = "failed"
)

type Transaction struct {
	ID            string
	SourceAccount int64
	DestAccount   int64
	Amount        float64
	Status        Status
	CreatedAt     time.Time
}

type Repository interface {
	Save(ctx context.Context, tx *Transaction) error
	GetByID(ctx context.Context, id string) (*Transaction, error)
}
