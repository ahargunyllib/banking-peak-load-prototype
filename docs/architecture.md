# System Architecture

## Overview

Defense-in-depth architecture with four protection layers between client and database. Each layer reduces load on the layer below it.

```
Client
  │
  ▼
┌──────────────────────────┐
│  Layer 1: Rate Limiter   │  Token bucket per client IP
│  (middleware)            │  Reject early → HTTP 429
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Layer 2: Circuit Breaker│  Monitor downstream health
│  (middleware)            │  Fail-fast → HTTP 503
└────────┬─────────┬───────┘
         │         │
       READ      WRITE
         │         │
         ▼         ▼
┌────────────┐ ┌──────────┐
│ Layer 3a:  │ │Layer 3b: │
│ Redis Cache│ │  Queue   │
│ (cache-    │ │(producer)│
│  aside)    │ │          │
└─────┬──────┘ └────┬─────┘
      │              │
      ▼              ▼
┌──────────┐  ┌────────────┐
│ Read     │  │  Worker    │
│ Replica  │  │ (consumer) │
└─────┬────┘  └─────┬──────┘
      │              │
      ▼              ▼
┌──────────────────────────┐
│  Layer 4: PostgreSQL     │
│  (via PgBouncer)         │
│  Primary: writes only    │
│  Replica: reads only     │
└──────────────────────────┘
```

## Read Path (Balance Inquiry, Transaction Status)

```
Request → Rate Limit Check → Circuit Breaker Check → Redis Cache Lookup
  ├── Cache HIT → Return cached data (HTTP 200)
  └── Cache MISS → Query Read Replica via PgBouncer
        → Store in Redis (TTL varies by data type)
        → Return data (HTTP 200)
```

### Cache TTLs
| Data | TTL | Rationale |
|------|-----|-----------|
| Account balance | 5-10s | Frequently accessed, slightly stale OK for inquiry |
| Transaction status (completed) | 30-60s | Immutable once settled |
| Transaction status (pending) | 2-3s | Changes frequently |

### Cache Invalidation
- On successful write (create transaction), invalidate `balance:{source_account}` and `balance:{dest_account}`
- On transaction status change (worker), invalidate `tx_status:{tx_id}`

## Write Path (Create Transaction)

### With Queue (Optimized)
```
Request → Rate Limit → Circuit Breaker → Validate Input
  → Generate TX ID → Publish to Queue → Return HTTP 202 + TX ID
  ...
  Worker picks up message → Begin DB Transaction
    → Check balance → Debit source → Credit dest → Insert TX record
    → Commit → Update TX status → Invalidate cache
```

### Without Queue (Baseline)
```
Request → Rate Limit → Circuit Breaker → Validate Input
  → Begin DB Transaction
    → Check balance → Debit source → Credit dest → Insert TX record
    → Commit → Return HTTP 201 + TX details
```

## Rate Limiting

- Algorithm: Token bucket
- Scope: Per client IP
- Config: `RATE_LIMIT_RPS` (sustained rate), `RATE_LIMIT_BURST` (burst allowance)
- Response on exceed: HTTP 429 with `Retry-After` header

## Circuit Breaker

- Library: `sony/gobreaker`
- Scope: Per downstream dependency (DB, cache, queue)
- States: Closed → Open → Half-Open → Closed
- Config: max failures before open, timeout duration, half-open max requests
- Response when open: HTTP 503

## Database

### Connection Management
- App connects to PgBouncer, not directly to PostgreSQL
- PgBouncer mode: transaction pooling
- Max connections: sized based on worker count + handler concurrency

### Schema (simplified)
```sql
accounts (
  id          BIGINT PRIMARY KEY,
  name        VARCHAR(255),
  balance     NUMERIC(18,2),
  updated_at  TIMESTAMPTZ
)

transactions (
  id              VARCHAR(26) PRIMARY KEY,  -- nanoid with prefix
  source_account  BIGINT REFERENCES accounts(id),
  dest_account    BIGINT REFERENCES accounts(id),
  amount          NUMERIC(18,2),
  status          VARCHAR(20),  -- pending, completed, failed
  created_at      TIMESTAMPTZ,
  updated_at      TIMESTAMPTZ
)
```

### Indexes
```sql
CREATE INDEX idx_transactions_source ON transactions(source_account);
CREATE INDEX idx_transactions_dest ON transactions(dest_account);
CREATE INDEX idx_transactions_status ON transactions(status) WHERE status = 'pending';
```

## Observability

### Metrics (Prometheus)
- `http_requests_total{method, path, status}` — Counter
- `http_request_duration_seconds{method, path}` — Histogram
- `cache_hits_total{key_type}` / `cache_misses_total{key_type}` — Counter
- `queue_depth` — Gauge
- `circuit_breaker_state{dependency}` — Gauge (0=closed, 1=open, 2=half-open)
- `db_connections_active` / `db_connections_idle` — Gauge

### Structured Logging
Every log line is JSON with at minimum:
```json
{
  "timestamp": "2025-...",
  "level": "info",
  "msg": "request completed",
  "trace_id": "abc123",
  "method": "GET",
  "path": "/api/v1/accounts/123/balance",
  "status": 200,
  "duration_ms": 12
}
```

### Trace ID
- Generated at API gateway (middleware) as UUID
- Propagated via `X-Trace-ID` header to all downstream calls
- Included in every log line and metric label where applicable
