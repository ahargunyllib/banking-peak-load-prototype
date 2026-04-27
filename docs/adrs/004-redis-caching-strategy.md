# ADR-004: Cache-Aside Strategy with Redis

## Status
Accepted

## Context
Read endpoints (balance inquiry, transaction status) are expected to dominate traffic (~70%). Without caching, every read hits the database, competing with writes for connections and I/O.

## Decision
Use Redis as a cache-aside (lazy-loading) cache for read path endpoints.

## Rationale
- **Cache-aside is simple.** App checks cache first. On miss, query DB, store result in cache. No background sync needed.
- **TTL-based expiry.** We don't need real-time consistency for inquiry endpoints. Balance can be 5-10s stale for read purposes. Transaction status for completed transactions is immutable.
- **Explicit invalidation on write.** When a transaction is created, invalidate balance cache for both accounts. This limits staleness to the write-then-read race window.
- **80% hit rate = 80% less DB read load.** This is the highest impact optimization with the least implementation effort.

## Cache Key Design
```
balance:{account_id}         → JSON of balance response
tx_status:{transaction_id}   → JSON of transaction status response
```

## TTL Strategy
| Key Pattern | TTL | Reason |
|-------------|-----|--------|
| `balance:*` | 5-10s | Balances change with transactions, short TTL limits staleness |
| `tx_status:*` (completed/failed) | 30-60s | Terminal states don't change |
| `tx_status:*` (pending) | 2-3s | May transition soon |

## Invalidation
- `POST /transactions` success → DELETE `balance:{source}`, `balance:{dest}`
- Worker status update → DELETE `tx_status:{tx_id}`

## Consequences
- Possible stale reads within TTL window. Acceptable for inquiry endpoints.
- Redis becomes a dependency. Circuit breaker protects against Redis failure (fall through to DB on cache error).
- Memory sizing: with 100K accounts and 26-byte keys + ~200-byte values, total cache footprint is <50MB.
