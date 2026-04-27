# Git Workflow

## Branch Strategy

Single main branch with short-lived feature branches.

```
main (always deployable via docker compose)
 ├── feat/rate-limiter
 ├── feat/redis-cache
 ├── feat/queue-write-path
 ├── feat/circuit-breaker
 ├── feat/pgbouncer-setup
 ├── feat/prometheus-grafana
 ├── feat/k6-load-tests
 └── fix/connection-pool-leak
```

### Rules
- `main` is protected — no direct pushes
- All changes go through feature branches + pull request
- Feature branches should be short-lived (1-3 days max)
- Squash merge to main for clean history
- Delete branch after merge

### Branch Naming

```
feat/   — new feature (feat/redis-cache)
fix/    — bug fix (fix/queue-consumer-deadlock)
docs/   — documentation only (docs/adr-006-backpressure)
refactor/ — code restructure (refactor/repository-pattern)
test/   — test additions (test/k6-write-path)
infra/  — docker/config changes (infra/grafana-dashboards)
```

## Commit Convention

Use conventional commits:

```
feat: add rate limiting middleware
fix: prevent connection pool exhaustion under load
docs: add ADR for caching strategy
test: add k6 script for write path
infra: add prometheus scrape config
refactor: extract cache-aside logic to repository layer
```

## PR Checklist

- [ ] Feature flag added if new optimization component
- [ ] Works with flag OFF (doesn't break baseline)
- [ ] Works with flag ON (feature functions correctly)
- [ ] Relevant docker-compose profile updated if new service
- [ ] Load test script updated/added if endpoint behavior changed
- [ ] Structured logging with trace_id included
