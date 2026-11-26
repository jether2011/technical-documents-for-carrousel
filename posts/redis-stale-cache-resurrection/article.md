# The database was right. Redis brought the old value back.

## A race hidden by a successful commit

PostgreSQL can contain the correct value while Redis still contains a stale snapshot. In cache-aside architectures, database commits, invalidations, and in-flight cache fills are independent operations.

An illustrative interleaving:

1. Reader A misses Redis and loads version 7 from PostgreSQL.
2. Writer B commits version 8.
3. Writer B invalidates the Redis key.
4. Reader A writes its stale version 7 into Redis.
5. New readers see version 7 despite version 8 being durable in PostgreSQL.

This is a concurrency example, not a claim about a specific production incident.

## Why a TTL alone does not fix it

TTL bounds the duration of possible staleness. It does not prevent an old in-flight loader from repopulating the key.

## Versions and a fencing strategy

Keep a monotonic version in the authoritative PostgreSQL row. A cached snapshot carries that version. Redis must atomically reject writes that are older than an already-observed version.

```java
record ProductSnapshot(long id, BigDecimal price, long version) {}
```

Example Redis Lua comparison:

```lua
local stored = redis.call('HGET', KEYS[1], 'version')
if stored and tonumber(stored) > tonumber(ARGV[1]) then
  return 0
end
redis.call('HSET', KEYS[1], 'version', ARGV[1], 'payload', ARGV[2])
redis.call('EXPIRE', KEYS[1], ARGV[3])
return 1
```

**Important limitation:** comparison against the cached value alone fails after deletion, because an empty key carries no newer version. Use a separate monotonic fence/tombstone, or coordinate authoritative version checks with cache publication; account for in-flight loaders and expiry.

## Durable invalidation is a separate problem

A transactional outbox can durably record a change in the same PostgreSQL transaction. A consumer can invalidate or refresh Redis asynchronously. This improves delivery reliability but does not give atomic cross-store transactions. Consumers still need idempotency, ordering rules, and version checks.

## Engineering trade-offs

- When read-after-write correctness is mandatory, bypass the cache or add coordination.
- When bounded staleness is acceptable, explicit TTL and metrics may be sufficient.
- A read-through or cache-aside abstraction does not automatically give serializable semantics.
- A cache is a replica with operational concerns: ordering, expiry, delivery and repair.

## Operational checklist

1. Define freshness budgets per endpoint.
2. Trace source and cached versions.
3. Test interleavings with barriers and concurrent readers/writers.
4. Alert on version regressions and stale fills.
5. Verify serialization and TTL behavior.
6. Measure latency, hit ratio, and correctness together.

## Official references

- [Spring Data Redis cache](https://docs.spring.io/spring-data/redis/reference/redis/redis-cache.html)
- [Redis cache-aside](https://redis.io/docs/latest/develop/use-cases/cache-aside/)
- [Redis client-side invalidation](https://redis.io/docs/latest/develop/use/client-side-caching/)
