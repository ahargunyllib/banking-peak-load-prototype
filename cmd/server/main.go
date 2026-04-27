package main

import (
	"github.com/ahargunyllib/banking-peak-load-prototype/internal/handler"
	"github.com/ahargunyllib/banking-peak-load-prototype/internal/repository/memory"
	"github.com/labstack/echo/v5"
)

func main() {
	accountRepo := memory.NewAccountRepository()
	txRepo := memory.NewTransactionRepository()

	accountHandler := handler.NewAccountHandler(accountRepo)
	txHandler := handler.NewTransactionHandler(txRepo)

	e := echo.New()

	e.GET("/api/v1/accounts/:id/balance", accountHandler.GetBalance)
	e.POST("/api/v1/transactions", txHandler.CreateTransaction)
	e.GET("/api/v1/transactions/:id/status", txHandler.GetTransactionStatus)

	e.Start(":8080")
}
