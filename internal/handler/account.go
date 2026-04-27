package handler

import (
	"net/http"
	"strconv"

	"github.com/ahargunyllib/banking-peak-load-prototype/internal/domain/account"
	"github.com/labstack/echo/v5"
)

type AccountHandler struct {
	repo account.Repository
}

func NewAccountHandler(repo account.Repository) *AccountHandler {
	return &AccountHandler{repo: repo}
}

func (h *AccountHandler) GetBalance(c *echo.Context) error {
	idStr := c.Param("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid account id"})
	}

	acc, err := h.repo.GetByID(c.Request().Context(), id)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "account not found"})
	}

	return c.JSON(http.StatusOK, map[string]any{
		"id":         acc.ID,
		"name":       acc.Name,
		"balance":    acc.Balance,
		"updated_at": acc.UpdatedAt,
	})
}
