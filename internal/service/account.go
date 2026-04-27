package service

import (
	"context"

	"github.com/ahargunyllib/banking-peak-load-prototype/internal/domain/account"
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
	return s.repo.GetByID(ctx, id)
}
