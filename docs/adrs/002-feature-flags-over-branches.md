# ADR-002: Feature Flags Over Separate Branches

## Status
Accepted

## Context
We need to maintain a baseline (no optimization) and an optimized version for comparison. Options considered:
1. Separate git branches per configuration
2. Separate folders with duplicated code
3. Feature flags + Docker Compose profiles in a single codebase

## Decision
Use feature flags (env vars) combined with Docker Compose profiles in a single branch.

## Rationale
- **Branches diverge.** Bug fixes and schema changes would need cherry-picking across branches. After a few weeks, fair comparison becomes impossible.
- **Folders duplicate.** Same handler code copied 3 times. Any change requires updating all copies.
- **Flags keep it DRY.** One codebase, toggling behavior via env vars. Comparison is fair because the only difference is the flag, not the code.
- **Industry standard.** Feature flags are how production systems do gradual rollout. Team learns a real pattern.
- **Demo-friendly.** Switch `.env` file and re-run compose. No branch checkout, no rebuild.

## Implementation
- Application: env vars like `CACHE_ENABLED`, `QUEUE_ENABLED`, etc.
- Infrastructure: Docker Compose `profiles` for optional services (Redis, RabbitMQ, replica)
- Presets: `.env.baseline` and `.env.optimized` checked into repo

## Consequences
- Slightly more conditional logic in middleware/repository layer
- Must ensure flag-off path is always tested (baseline must not break)
- Need clear preset files to avoid confusion during demos
