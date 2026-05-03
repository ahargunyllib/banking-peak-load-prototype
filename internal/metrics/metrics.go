package metrics

import "github.com/prometheus/client_golang/prometheus"

var (
	CacheHits = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "cache_hits_total",
		Help: "Total number of Redis cache hits.",
	}, []string{"key_type"})

	CacheMisses = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "cache_misses_total",
		Help: "Total number of Redis cache misses.",
	}, []string{"key_type"})

	CircuitBreakerOpen = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "circuit_breaker_open",
		Help: "1 when the circuit breaker is open, 0 when closed.",
	})

	DBConnectionsActive = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "db_connections_active",
		Help: "Number of active (in-use) database connections.",
	})

	DBConnectionsIdle = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "db_connections_idle",
		Help: "Number of idle database connections in the pool.",
	})
)

func init() {
	prometheus.MustRegister(
		CacheHits,
		CacheMisses,
		CircuitBreakerOpen,
		DBConnectionsActive,
		DBConnectionsIdle,
	)
}
