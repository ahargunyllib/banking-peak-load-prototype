package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ahargunyllib/banking-peak-load-prototype/internal/handler"
	"github.com/ahargunyllib/banking-peak-load-prototype/internal/logger"
	appmw "github.com/ahargunyllib/banking-peak-load-prototype/internal/middleware"
	"github.com/ahargunyllib/banking-peak-load-prototype/internal/repository/memory"
	"github.com/ahargunyllib/banking-peak-load-prototype/internal/service"
	"github.com/labstack/echo/v5"
	"github.com/labstack/echo/v5/middleware"
)

func main() {
	logger.Init()

	accountRepo := memory.NewAccountRepository()
	txRepo := memory.NewTransactionRepository()

	accountSvc := service.NewAccountService(accountRepo)
	txSvc := service.NewTransactionService(txRepo)

	accountHandler := handler.NewAccountHandler(accountSvc)
	txHandler := handler.NewTransactionHandler(txSvc)

	e := echo.New()
	e.Logger = logger.L                    // route Echo's internal logs through our slog JSON logger
	e.Use(middleware.BodyLimit(2_097_152)) // 2MB
	e.Use(middleware.ContextTimeout(60 * time.Second))
	// e.Use(middleware.CORS("https://example.com")) // Allow CORS from frontend domain in real deployment
	e.Use(middleware.CSRF())
	e.Use(middleware.Decompress())
	e.Use(middleware.GzipWithConfig(middleware.GzipConfig{
		Level: 5,
	}))
	e.Use(middleware.RateLimiter(middleware.NewRateLimiterMemoryStore(20.0)))
	e.Use(middleware.Recover())
	e.Use(middleware.RequestID()) // sets X-Request-ID header; must run before RequestLogger
	e.Use(appmw.RequestLogger())  // wide event canonical log line
	e.Use(middleware.Secure())

	e.GET("/api/v1/accounts/:id/balance", accountHandler.GetBalance)
	e.POST("/api/v1/transactions", txHandler.CreateTransaction)
	e.GET("/api/v1/transactions/:id/status", txHandler.GetTransactionStatus)

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM) // start shutdown process on signal
	defer cancel()

	sc := echo.StartConfig{
		Address:         ":8080",
		GracefulTimeout: 5 * time.Second, // defaults to 10 seconds
	}

	if err := sc.Start(ctx, e); err != nil {
		e.Logger.Error("failed to start server", "error", err)
	}
}
