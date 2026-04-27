package service

import (
	"context"
	"fmt"
	"time"

	"github.com/ahargunyllib/banking-peak-load-prototype/internal/domain/transaction"
)

type CreateTransactionInput struct {
	SourceAccount int64
	DestAccount   int64
	Amount        float64
}

type TransactionService interface {
	CreateTransaction(ctx context.Context, input CreateTransactionInput) (*transaction.Transaction, error)
	GetTransactionStatus(ctx context.Context, id string) (*transaction.Transaction, error)
}

type transactionService struct {
	repo transaction.Repository
}

func NewTransactionService(repo transaction.Repository) TransactionService {
	return &transactionService{repo: repo}
}

func (s *transactionService) CreateTransaction(ctx context.Context, input CreateTransactionInput) (*transaction.Transaction, error) {
	tx := &transaction.Transaction{
		ID:            fmt.Sprintf("tx_%d", time.Now().UnixNano()),
		SourceAccount: input.SourceAccount,
		DestAccount:   input.DestAccount,
		Amount:        input.Amount,
		Status:        transaction.StatusCompleted,
		CreatedAt:     time.Now(),
	}

	if err := s.repo.Save(ctx, tx); err != nil {
		return nil, err
	}

	return tx, nil
}

func (s *transactionService) GetTransactionStatus(ctx context.Context, id string) (*transaction.Transaction, error) {
	return s.repo.GetByID(ctx, id)
}
