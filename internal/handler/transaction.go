package handler

import (
	"fmt"
	"net/http"
	"time"

	"github.com/ahargunyllib/banking-peak-load-prototype/internal/domain/transaction"
	"github.com/ahargunyllib/banking-peak-load-prototype/internal/handler/request"
	"github.com/labstack/echo/v5"
)

type TransactionHandler struct {
	repo transaction.Repository
}

func NewTransactionHandler(repo transaction.Repository) *TransactionHandler {
	return &TransactionHandler{repo: repo}
}

func (h *TransactionHandler) CreateTransaction(c *echo.Context) error {
	var req request.CreateTransaction
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}
	if req.SourceAccount == 0 || req.DestAccount == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "source_account and dest_account are required"})
	}
	if req.Amount <= 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "amount must be greater than 0"})
	}

	tx := &transaction.Transaction{
		ID:            fmt.Sprintf("tx_%d", time.Now().UnixNano()),
		SourceAccount: req.SourceAccount,
		DestAccount:   req.DestAccount,
		Amount:        req.Amount,
		Status:        transaction.StatusCompleted,
		CreatedAt:     time.Now(),
	}

	if err := h.repo.Save(c.Request().Context(), tx); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to save transaction"})
	}

	return c.JSON(http.StatusCreated, map[string]any{
		"id":             tx.ID,
		"source_account": tx.SourceAccount,
		"dest_account":   tx.DestAccount,
		"amount":         tx.Amount,
		"status":         tx.Status,
		"created_at":     tx.CreatedAt,
	})
}

func (h *TransactionHandler) GetTransactionStatus(c *echo.Context) error {
	id := c.Param("id")
	if id == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "id is required"})
	}

	tx, err := h.repo.GetByID(c.Request().Context(), id)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "transaction not found"})
	}

	return c.JSON(http.StatusOK, map[string]any{
		"id":             tx.ID,
		"source_account": tx.SourceAccount,
		"dest_account":   tx.DestAccount,
		"amount":         tx.Amount,
		"status":         tx.Status,
		"created_at":     tx.CreatedAt,
	})
}
