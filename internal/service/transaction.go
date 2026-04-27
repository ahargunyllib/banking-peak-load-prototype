package service

import (
	"context"
	"fmt"
	"time"

	"github.com/ahargunyllib/banking-peak-load-prototype/internal/domain/transaction"
	"github.com/ahargunyllib/banking-peak-load-prototype/internal/logger"
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
	logger.Set(ctx, "source_account", input.SourceAccount)
	logger.Set(ctx, "dest_account", input.DestAccount)
	logger.Set(ctx, "amount", input.Amount)

	tx := &transaction.Transaction{
		ID:            fmt.Sprintf("tx_%d", time.Now().UnixNano()),
		SourceAccount: input.SourceAccount,
		DestAccount:   input.DestAccount,
		Amount:        input.Amount,
		Status:        transaction.StatusCompleted,
		CreatedAt:     time.Now(),
	}

	if err := s.repo.Save(ctx, tx); err != nil {
		logger.Set(ctx, "transaction_error", err.Error())
		return nil, err
	}

	logger.Set(ctx, "transaction_id", tx.ID)
	logger.Set(ctx, "transaction_status", tx.Status)
	return tx, nil
}

func (s *transactionService) GetTransactionStatus(ctx context.Context, id string) (*transaction.Transaction, error) {
	logger.Set(ctx, "transaction_id", id)

	tx, err := s.repo.GetByID(ctx, id)
	if err != nil {
		logger.Set(ctx, "transaction_error", err.Error())
		return nil, err
	}

	logger.Set(ctx, "transaction_status", tx.Status)
	return tx, nil
}
