---
title: "Your H2 Tests Passed. PostgreSQL Still Broke Production."
slug: h2-postgresql-test-fidelity
language: en
created: 2026-11-25
status: scheduled
---

# Your H2 Tests Passed. PostgreSQL Still Broke Production.

> A green repository test proves only what its database actually executed.

## Executive overview

A green repository test proves only what its database actually executed. H2 and PostgreSQL differ in SQL parsing, constraints, type coercion, indexes, locks and planner behavior. This is a constructed engineering example, not a claim about an actual outage or employer.

## Root cause

H2 and PostgreSQL differ in SQL parsing, constraints, type coercion, indexes, locks and planner behavior. Abstractions simplify the API surface, but the operational behavior still depends on the real implementation and resource boundaries. A passing happy-path test or fast single query is useful evidence, not proof that a complete production request is correct and fast.

## Architecture and implementation

Run repository integration tests with PostgreSQL Testcontainers, real migrations, edge-case parameters, and concurrency tests. Define the relevant contract: what the caller expects, which component owns the behavior, how resources are bounded, and what metrics prove the design. Consider deployments, concurrent execution and retry behavior.

```java
@Container static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:17");
```

This code is an illustrative sketch and needs adaptation and integration testing before production use.

## Trade-offs

Testcontainers improves fidelity but does not match production volume, network or contention. Benchmark with representative data and traffic; avoid assuming a single successful test covers runtime resource limits.

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

- https://java.testcontainers.org/modules/databases/postgres/
- https://www.postgresql.org/docs/current/sql-explain.html

## Conclusion

Reliable systems come from examining actual boundaries, not mistaking abstraction for operational guarantees.
