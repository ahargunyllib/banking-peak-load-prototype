# PRD: Banking Peak Load Management Prototype

## Problem Statement

A major bank (inspired by CIMB Niaga) experiences system crashes during peak load periods (1M transactions/hour). Root causes:

1. Architecture not ready for scale — API and database bottlenecks cause overload
2. No load shedding or backpressure — system accepts all traffic until it dies
3. Database bottlenecks — heavy queries, connection exhaustion, lock contention
4. No caching or read/write separation
5. No SLO-based monitoring — scaling decisions are reactive, not proactive

## Project Goal

Build a prototype peak load management architecture that:

1. Maintains service availability under simulated peak load
2. Measurably reduces p95 latency compared to baseline
3. Implements protection mechanisms (rate limit, queue, circuit breaker, backpressure)
4. Implements scalability strategies (caching, read/write separation, async processing)
5. Provides observability and capacity planning based on SLO targets

## Target Users

University evaluators and CIMB Niaga representatives reviewing the prototype.

## Functional Requirements

### FR-1: Create Transaction (Write Path)
- Accept transaction payload (source account, destination account, amount)
- Validate input (format, required fields, positive amount)
- When queue enabled: publish to message queue, return HTTP 202 with transaction ID
- When queue disabled (baseline): process synchronously, return HTTP 201
- Worker consumes from queue, executes DB transaction (check balance, debit, credit), updates status
- Invalidate related cache entries after write

### FR-2: Transaction Status Inquiry (Read Path)
- Accept transaction ID
- Check Redis cache first (when enabled)
- On cache miss, query read replica (or primary if replica disabled)
- Cache result with TTL (short for pending, longer for completed)
- Return transaction status and details

### FR-3: Balance Inquiry (Read Path)
- Accept account ID
- Check Redis cache first (when enabled)
- On cache miss, query read replica (or primary if replica disabled)
- Cache result with short TTL (5-10s)
- Return current balance

### FR-4: Rate Limiting
- Token bucket per client IP
- Return HTTP 429 when quota exceeded
- Configurable rate and burst size via env var

### FR-5: Circuit Breaker
- Monitor error rate per downstream dependency
- Open circuit when threshold exceeded (e.g., 50% errors in 10s window)
- Return HTTP 503 when circuit open
- Half-open state for periodic retry

### FR-6: Observability
- Expose Prometheus metrics: request count by status, latency histogram, queue depth, cache hit/miss ratio, DB connection pool stats
- Structured JSON logging with trace ID propagated across all components
- Grafana dashboards for SLO tracking

### FR-7: Load Testing
- k6 scripts simulating realistic traffic distribution (70% read, 30% write)
- Configurable virtual users and duration
- Output: p50/p95/p99 latency, TPS, error rate
- Scripts for both baseline and optimized configurations

## Non-Functional Requirements

- All components run via Docker Compose on a single machine (8GB RAM minimum)
- Feature flags toggle each optimization layer independently
- Dummy dataset: 1-5M transaction records, 10K-100K accounts
- No cloud dependency — fully local development

## Out of Scope

- Real banking logic (KYC, actual fund transfer, etc.)
- Production cloud deployment
- Full Kubernetes orchestration (conceptual only)
- Multi-region / disaster recovery
- Authentication/authorization (simplified or skipped)

## Success Criteria

Quantitative comparison between baseline and optimized configurations:

| Metric | Baseline Target | Optimized Target |
|--------|----------------|-----------------|
| p95 Latency (read) | > 2s | < 500ms |
| p95 Latency (write) | > 5s | < 2s |
| Error Rate at peak | > 20% | < 0.5% |
| Max TPS | < 100 | > 300 |
| Cache Hit Rate | N/A | > 80% |

## Milestones

### Phase 1: Baseline (Week 1-3)
- Go service with 3 endpoints
- PostgreSQL with dummy data
- k6 load test scripts
- Baseline metrics captured

### Phase 2: Protection & Optimization (Week 4-8)
- PgBouncer + index optimization
- Redis caching for read path
- Rate limiting middleware
- Message queue for write path
- Circuit breaker
- Per-component load test comparison

### Phase 3: Observability & Reporting (Week 9-12)
- Prometheus + Grafana setup
- SLO dashboard
- Structured logging + trace ID
- Capacity planning report
- Final baseline vs optimized comparison report
