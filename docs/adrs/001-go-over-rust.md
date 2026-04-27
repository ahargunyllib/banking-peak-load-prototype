# ADR-001: Go Over Rust as Primary Language

## Status
Accepted

## Context
We need a language for the backend prototype that handles high concurrency well. The two strongest candidates are Go and Rust.

## Decision
Use Go.

## Rationale
- **Team velocity:** This is a 3-SKS project with cross-major team members (SI, TI, IT, TK). Go's learning curve is significantly shorter. Rust's borrow checker and lifetime system require weeks of investment before productivity.
- **Concurrency model:** Goroutines are lightweight and map well to our use case (many concurrent HTTP requests + queue workers). Rust's async model (tokio) is powerful but harder to debug.
- **Ecosystem maturity:** Libraries we need (pgx, go-redis, gobreaker, prometheus client, chi/echo) are battle-tested and well-documented.
- **Diminishing returns:** Our bottleneck is database I/O and network latency, not CPU-bound computation in the application layer. The performance difference between Go and Rust is negligible for this workload.

## Consequences
- Accept GC pauses (typically <1ms in Go 1.22+), which are invisible at our target p95 of 500ms.
- Team can be productive within week 1.
- If we ever need Rust-level performance, the architecture (stateless services) allows rewriting individual components without redesign.
