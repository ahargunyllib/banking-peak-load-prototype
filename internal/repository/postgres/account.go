package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/ahargunyllib/banking-peak-load-prototype/internal/domain/account"
	"github.com/jmoiron/sqlx"
)

type AccountRepository struct{ db *sqlx.DB }

func NewAccountRepository(db *sqlx.DB) *AccountRepository {
	return &AccountRepository{db: db}
}

func (r *AccountRepository) GetByID(ctx context.Context, id int64) (*account.Account, error) {
	var a account.Account
	err := r.db.GetContext(ctx, &a,
		`SELECT id, name, balance, updated_at FROM accounts WHERE id = $1`, id)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("account %d not found", id)
	}
	if err != nil {
		return nil, err
	}
	return &a, nil
}
