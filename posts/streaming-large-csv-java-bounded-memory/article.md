# A 10 GB CSV File Is a Backpressure Problem, Not a Heap Problem

**Engineering note | Java, Spring Batch, PostgreSQL**

A common failure mode in large-file imports is treating the file as a collection: read everything, validate everything, then save everything. A 10 GB CSV cannot fit inside a JVM configured with a 512 MB heap. Fortunately, the application does not need the entire dataset in memory. It needs one record, a bounded number of pending writes, and a durable record of progress.

## 1. The real memory budget

A stream reduces how much input is resident at once. But the pipeline only stays bounded if **every stage** has bounded memory use: parser buffers, validation, aggregation, database batches, retry buffers, error handling, and metrics.

Avoid code like:

```java
List<String> lines = Files.readAllLines(path);
List<Row> rows = lines.stream().map(this::parse).toList();
repository.saveAll(rows);
```

Both lists scale with input size. Likewise, `stream.toList()` materializes the stream; a stream does not guarantee bounded memory if the terminal stage collects everything.

## 2. Parse CSV records, not naïvely split lines

RFC 4180 permits quoted fields that contain delimiters and line breaks. `String.split(",")` is insufficient for general CSV, and blindly counting physical lines may not count CSV records.

Using Apache Commons CSV with a `Reader` provides a record iterator:

```java
try (Reader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8);
     CSVParser parser = CSVFormat.RFC4180.builder()
         .setHeader()
         .setSkipHeaderRecord(true)
         .get()
         .parse(reader)) {

    for (CSVRecord record : parser) {
        String id = record.get("id");
        String amount = record.get("amount");
        // Validate and send into a bounded writer.
    }
}
```

The iterator helps avoid loading every record. **Limits still apply:** an individual field can be extremely large, and some parser features may retain metadata or records in memory. Define maximum field sizes and application limits, and benchmark the chosen parser version under worst-case inputs.

## 3. Batch database writes, but bound them

Use a batch sized for memory and database latency. For example, keep at most 500 validated records pending:

```java
List<ValidatedRow> batch = new ArrayList<>(500);
for (CSVRecord csv : parser) {
    batch.add(validate(csv));
    if (batch.size() == 500) {
        writer.write(batch); // parameterized JDBC batch
        batch.clear();
    }
}
if (!batch.isEmpty()) {
    writer.write(batch);
}
```

The database writer should commit controlled chunks. Make every row or chunk idempotent (for example, a unique import_id plus source_record_number) so a retried chunk cannot create duplicates. Batch sizing is workload-dependent: start with an explicit bound and measure memory usage, locks and throughput.

## 4. Backpressure is end-to-end

If validation takes 2,000 records per second and the database accepts only 300, an unbounded queue grows forever until memory fails.

Use either a sequential reader-writer pipeline or a small fixed-capacity queue with a bounded worker count. A blocked producer is a feature here: it prevents the producer from outrunning the durable sink.

Track queue depth and time blocked on database writes, not only records per second.

## 5. Restartability: where progress becomes durable

A progress marker is only meaningful if it corresponds to **committed rows**. Writing a checkpoint before the transaction commits can skip data after a crash. Updating it too late can repeat the final chunk.

Spring Batch provides JobRepository and ExecutionContext facilities for restartability, coupled with chunk transactions. For a custom pipeline, persist an import ID, file fingerprint and committed record index alongside the batch state. On restart, validate the source file is the same and replay from a safe boundary with idempotency.

For CSV, quoted multiline fields mean a byte offset or physical line index may not be a valid record boundary. Either use parser-supported state / consistent record counts or store a safe seek boundary with enough parsing context.

## 6. Aggregations and sorting

Counts and sums are usually constant-space; high-cardinality `groupBy` and full sorting are not. Use database-side aggregation, partitioning or external merge sort when the state does not fit into memory. Avoid silently collecting data for `distinct`, `sorted` or `groupingBy`.

## 7. PostgreSQL COPY is a tool, not a universal replacement

If the target is PostgreSQL and transformation needs are light, pgJDBC provides a `CopyManager` API for fast bulk import. Consider COPY into a staging table and perform validation, deduplication and merging with SQL. When per-row business checks are complex, a JDBC batch or Spring Batch ItemProcessor may make the workflow clearer.

```java
PGConnection pg = connection.unwrap(PGConnection.class);
CopyManager copy = pg.getCopyAPI();
// Feed a validated stream into COPY for a staging table.
```

COPY does not eliminate correctness obligations: transaction semantics, malformed input, conflicts, auditing and restart behavior still matter.

## 8. Production checklist

- Define memory limits for each stage, including maximum record size.
- Parse CSV according to the actual dialect, quoting and encoding.
- Keep queues and write buffers bounded.
- Use chunk transactions and idempotent keys.
- Advance checkpoints only after durable writes.
- Test crash recovery at every chunk boundary.
- Monitor heap, GC pauses, queue depth, database wait and input throughput.
- Test malformed CSV, multiline fields, bad encodings and huge cells.
- Decide whether the business can tolerate partial imports; use staging tables for all-or-nothing workflows.

### Further reading (official)

- [Spring Batch: chunk-oriented processing](https://docs.spring.io/spring-batch/reference/6.1/step/chunk-oriented-processing.html)
- [Spring Batch: execution context and restartability](https://docs.spring.io/spring-batch/reference/domain.html)
- [Apache Commons CSV: CSVParser](https://commons.apache.org/proper/commons-csv/apidocs/org/apache/commons/csv/CSVParser.html)
- [pgJDBC: CopyManager](https://jdbc.postgresql.org/documentation/server-prepare/)

**Bottom line:** A large CSV pipeline is a flow-control and recovery system. Treat memory as a strict budget; don't let faster upstream stages turn it into an accidental queue.
