---
title: "The SQL Takes 12 ms. Why Does the API Take 900 ms?"
slug: slow-java-endpoint-fast-sql
language: en
created: 2026-11-25
status: scheduled
---

# The SQL Takes 12 ms. Why Does the API Take 900 ms?

> A fast SQL query does not guarantee a fast HTTP request.

## Executive overview

A fast SQL query does not guarantee a fast HTTP request. Requests include connection wait, SQL execution, row transfer, hydration, object mapping, JSON serialization and response writes. This is a constructed engineering example, not a claim about an actual outage or employer.

## Root cause

Requests include connection wait, SQL execution, row transfer, hydration, object mapping, JSON serialization and response writes. Abstractions simplify the API surface, but the operational behavior still depends on the real implementation and resource boundaries. A passing happy-path test or fast single query is useful evidence, not proof that a complete production request is correct and fast.

## Architecture and implementation

Instrument pool acquisition, SQL time, ORM hydration, DTO mapping, response bytes and end-to-end latency under representative load. Define the relevant contract: what the caller expects, which component owns the behavior, how resources are bounded, and what metrics prove the design. Consider deployments, concurrent execution and retry behavior.

```java
// Watch HikariCP pending/active, SQL spans, p95 HTTP latency, response bytes.
```

This code is an illustrative sketch and needs adaptation and integration testing before production use.

## Trade-offs

A faster index will not solve waiting for a connection or expensive serialization. Benchmark with representative data and traffic; avoid assuming a single successful test covers runtime resource limits.

## Production checklist

- Define an explicit operational contract for the dependency.
- Test failure cases and boundary inputs, not only happy paths.
- Apply the actual schema and infrastructure constraints.
- Measure p95 and p99 latency and resource contention.
- Confirm behavior under concurrent traffic.
- Document rollback and incident diagnostics.
- Track regression checks in CI.

## Questions for an architecture review

1. What exactly has the current test demonstrated?
2. Which runtime boundary is outside the measurement?
3. Can the same code fail when data size or concurrency changes?
4. What would an on-call engineer inspect first?
5. Which signal would confirm the fix worked?

## Further reading

- https://github.com/brettwooldridge/HikariCP
- https://opentelemetry.io/docs/languages/java/

## Conclusion

Reliable systems come from examining actual boundaries, not mistaking abstraction for operational guarantees.
