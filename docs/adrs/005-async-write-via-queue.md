# ADR-005: Asynchronous Write Path via Message Queue

## Status
Accepted

## Context
The create transaction endpoint is write-heavy and involves multiple DB operations within a transaction (check balance, debit, credit, insert record). Under peak load, synchronous writes saturate database connections and increase latency for all requests.

## Decision
Use a message queue (RabbitMQ or Redis Streams) to decouple the write path. The API publishes to the queue and returns HTTP 202 immediately. A pool of worker processes consumes and executes the actual DB transaction.

## Options Considered
| Option | Pros | Cons |
|--------|------|------|
| RabbitMQ | Mature, durable, ACK/NACK, dead-letter queue | Extra container, more config |
| Redis Streams | Already have Redis for cache, consumer groups built-in | Less mature for job queue patterns, shared resource with cache |
| Kafka | High throughput, replay capability | Overkill for prototype, complex setup |

## Decision Detail
Start with RabbitMQ for clear separation of concerns (cache vs queue). If team finds operational overhead too high, fall back to Redis Streams since Redis is already in the stack.

## Rationale
- **Backpressure.** Queue absorbs burst traffic. Workers consume at a controlled rate matching DB capacity.
- **Decoupling.** API response time is independent of DB write time. Client gets fast acknowledgment.
- **Controlled concurrency.** Worker pool size (e.g., 10) caps parallel DB transactions, preventing connection exhaustion from write spikes.
- **Eventual consistency.** Acceptable for this use case. Client can poll transaction status endpoint to check completion.

## Flow
```
Client POST /transactions
  → API validates input
  → Generate transaction ID (nanoid with prefix, e.g., tx_01J...)
  → Insert to queue: {tx_id, source, dest, amount}
  → Return HTTP 202 {transaction_id: "tx_01J...", status: "pending"}

Worker (N concurrent):
  → Dequeue message
  → BEGIN transaction
  → SELECT balance FROM accounts WHERE id = source FOR UPDATE
  → Check balance >= amount
  → UPDATE accounts SET balance = balance - amount WHERE id = source
  → UPDATE accounts SET balance = balance + amount WHERE id = dest
  → INSERT INTO transactions (...)
  → COMMIT
  → Invalidate cache keys
  → ACK message (or NACK + dead-letter on failure)
```

## Consequences
- Client must poll for transaction result (adds complexity to load test script)
- Need dead-letter queue strategy for poison messages
- Worker failure handling: messages re-queued on NACK, must be idempotent (use tx_id as idempotency key)
- Queue depth becomes a key observability metric
