package service

import (
	"context"

	"github.com/ahargunyllib/banking-peak-load-prototype/internal/domain/account"
	"github.com/ahargunyllib/banking-peak-load-prototype/internal/logger"
)

type AccountService interface {
	GetBalance(ctx context.Context, id int64) (*account.Account, error)
}

type accountService struct {
	repo account.Repository
}

func NewAccountService(repo account.Repository) AccountService {
	return &accountService{repo: repo}
}

func (s *accountService) GetBalance(ctx context.Context, id int64) (*account.Account, error) {
	logger.Set(ctx, "account_id", id)

	acc, err := s.repo.GetByID(ctx, id)
	if err != nil {
		logger.Set(ctx, "account_error", err.Error())
		return nil, err
	}

	logger.Set(ctx, "account_balance", acc.Balance)
	return acc, nil
}
