# ADR-003: PgBouncer for Connection Pooling

## Status
Accepted

## Context
Under peak load, each goroutine handling an HTTP request may open a database connection. PostgreSQL has a hard limit on max connections (~100-200 default), far lower than concurrent goroutines we expect during load tests (hundreds to thousands).

## Decision
Use PgBouncer in transaction pooling mode between the application and PostgreSQL.

## Rationale
- **Connection multiplexing:** PgBouncer can serve thousands of application connections using a small pool of actual PostgreSQL connections (e.g., 20-30).
- **Go's pgx pool is not enough:** pgx has its own connection pool, but it manages connections at the application level. Under heavy load, the app-level pool still competes with PostgreSQL's connection limit. PgBouncer sits between and manages this more efficiently.
- **Transaction pooling mode:** Each transaction gets a connection, released immediately after commit. This maximizes connection reuse for our short-lived queries.
- **Zero code change:** The app connects to PgBouncer using a standard PostgreSQL DSN. No library or driver changes needed.

## Consequences
- Cannot use prepared statements in transaction pooling mode (PgBouncer limitation). Use `PreferSimpleProtocol: true` in pgx config.
- Adds one more container to Docker Compose.
- Connection pool sizing must be tuned: PgBouncer pool size should match PostgreSQL max_connections, app-side pool can be much larger.

