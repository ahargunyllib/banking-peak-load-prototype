package logger

import (
	"context"
	"log/slog"
	"os"
)

type contextKey struct{}

// WideEvent is a mutable map built up throughout a request and emitted as a
// single canonical log line at completion (the "wide event" / canonical log
// line pattern).
type WideEvent map[string]any

var L *slog.Logger

// Init configures the global JSON logger. Call once at startup.
// Reads APP_VERSION, GIT_COMMIT, APP_ENV from the environment so every log
// line carries deployment context automatically.
func Init() {
	L = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	slog.SetDefault(L)
}

// NewEvent creates an empty WideEvent.
func NewEvent() WideEvent {
	return make(WideEvent)
}

// WithEvent attaches a WideEvent to the context so downstream services can
// enrich it with business fields.
func WithEvent(ctx context.Context, e WideEvent) context.Context {
	return context.WithValue(ctx, contextKey{}, e)
}

// EventFromContext returns the WideEvent stored in ctx, or nil.
func EventFromContext(ctx context.Context) WideEvent {
	e, _ := ctx.Value(contextKey{}).(WideEvent)
	return e
}

// Set adds a single field to the WideEvent in ctx. Safe to call when no event
// is present (no-op).
func Set(ctx context.Context, key string, val any) {
	if e := EventFromContext(ctx); e != nil {
		e[key] = val
	}
}

// Emit writes the WideEvent as a single flat JSON log line.
func Emit(ctx context.Context, e WideEvent) {
	attrs := make([]slog.Attr, 0, len(e))
	for k, v := range e {
		attrs = append(attrs, slog.Any(k, v))
	}
	L.LogAttrs(ctx, slog.LevelInfo, "request", attrs...)
}

// Error logs a structured error outside of a request wide event (e.g. startup
// failures).
func Error(msg string, args ...any) {
	L.Error(msg, args...)
}
