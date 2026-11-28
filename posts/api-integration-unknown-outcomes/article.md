# The API Returned a Timeout. Did the Payment Actually Fail?

An engineering guide to operating reliable external API integrations in Java and Spring.

A network timeout is an observation by the caller, **not proof of business failure**. A provider can commit a payment and lose the response. Robust integrations must represent this ambiguity explicitly rather than hide it behind an exception.

## 1. Model business outcomes, not just HTTP status

| State | Meaning | Response |
|---|---|---|
| SUCCEEDED | Provider confirms the outcome | Persist and complete |
| REJECTED | Definitive business rejection | Stop or correct input |
| UNKNOWN | Remote side effect may have happened | Query status / reconcile |
| TRANSIENT | Provider explicitly indicates retryable failure | Retry only when operation is safe |

A timeout after the provider may have accepted the command belongs to UNKNOWN until there is authoritative evidence.

## 2. Persist one idempotency key per command

For side-effecting requests, generate one idempotency key for the *logical operation*, not per attempt. Persist it with the operation so restarts and asynchronous workers reuse it.

```java
record TransferCommand(UUID commandId, UUID customerId,
                       BigDecimal amount) {}

String key = command.commandId().toString();
// Persist key and command status before calling the provider.
// Reuse the same key for any safe retry of this command.
```

The provider must support a compatible key contract; do not assume that an arbitrary header ensures idempotency. Verify retention windows, parameter matching and outcome retrieval. A new key for each retry can create duplicate side effects.

## 3. Isolate provider behavior behind an adapter

Spring Framework's RestClient is a fluent synchronous HTTP client. A provider adapter can turn transport details and provider-specific error payloads into a stable internal contract.

```java
final class ProviderClient {
  private final RestClient client;

  ProviderClient(RestClient.Builder builder, String baseUrl) {
    client = builder.baseUrl(baseUrl).build();
  }

  ProviderReceipt submit(TransferCommand command) {
    return client.post()
      .uri("/transfers")
      .header("Idempotency-Key", command.commandId().toString())
      .body(command)
      .retrieve()
      .onStatus(s -> s.value() == 429, (req, res) -> {
        throw new ProviderRateLimitedException();
      })
      .body(ProviderReceipt.class);
  }
}
```

Configure HTTP connection and response timeouts through the underlying request factory, validate response bodies, and map error classes. The `Idempotency-Key` header here is illustrative and depends on the provider's API.

## 4. A timeout budget is an end-to-end budget

The request can wait for a connection pool slot, DNS, TCP, TLS, a remote server, or an internal queue. A socket timeout is not necessarily an end-to-end deadline. Define a caller-level budget that also accounts for retries. Cancellation cannot reliably reverse a remote side effect.

## 5. Retries are conditional, bounded and observable

RFC 9110 warns against automatically retrying non-idempotent operations without knowledge that the request is safe to repeat. Retry only a documented transient failure class, with bounded attempts, exponential backoff and jitter as appropriate. Respect provider `Retry-After` and caller deadlines.

```java
RetryConfig cfg = RetryConfig.custom()
  .maxAttempts(3)
  .waitDuration(Duration.ofMillis(250))
  .retryExceptions(ProviderUnavailableException.class,
                   ProviderRateLimitedException.class)
  .build();

Retry retry = Retry.of("provider", cfg);
Supplier<ProviderReceipt> operation =
  Retry.decorateSupplier(retry, () -> provider.submit(command));
```

This is a partial illustration; coordinate exception mapping, jitter and total time budget in real code. Never stack multiple independent retries at every service hop: they can amplify outages.

## 6. Keep resilience controls distinct

- **Retry:** safely reattempt a transient failure.
- **Circuit breaker:** stop sending traffic during an outage.
- **Bulkhead:** bound concurrent resource demand.
- **Rate limiter:** manage request frequency.

A circuit breaker does not make a non-idempotent request safe. A fallback must not invent a successful payment.

## 7. Reconciliation belongs in the normal workflow

```text
Accept command -> persist operation + idempotency key
Submit to provider
  Confirmed -> record outcome
  Rejected  -> record reason
  Unknown   -> schedule reconciliation
Poll provider status or consume verified webhook
Settle, expire under policy, or escalate
```

Authenticate webhook signatures, deduplicate event IDs, and handle out-of-order messages. A transactional outbox can durably publish local follow-up work, but it does not make a database transaction atomic with the provider.

## 8. Production tests and observability

Test timeouts after remote commit, duplicated commands, conflicting idempotency payloads, malformed 200 responses, rate limiting, pool saturation, lost webhook deliveries and out-of-order events. Track latency by provider, retries per logical command, unknown-state age, connection wait, bulkhead saturation, reconciliation success and circuit breaker state. Keep credentials and sensitive payloads out of logs.

## Engineering checklist

- [ ] Define provider-specific outcome taxonomy.
- [ ] Persist business command and stable idempotency key.
- [ ] Use one deadline across connection wait, call and retry.
- [ ] Retry only demonstrably safe operations.
- [ ] Reconcile unknown states and audit outcomes.
- [ ] Test ambiguous completion and duplicate webhooks.
- [ ] Observe latency, retry amplification and unknown-state backlog.

## Official references

- [RFC 9110 — Idempotent methods](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.2)
- [Spring Framework — REST clients](https://docs.spring.io/spring-framework/reference/6.2/integration/rest-clients.html)
- [Resilience4j — Retry](https://resilience4j.readme.io/docs/retry)
- [Resilience4j — Circuit breaker](https://resilience4j.readme.io/docs/circuitbreaker)
- [OpenTelemetry — Distributed traces](https://opentelemetry.io/docs/concepts/signals/traces/)

The engineering maturity of an integration appears when the network stops giving definitive answers, not when the first HTTP 200 arrives.
