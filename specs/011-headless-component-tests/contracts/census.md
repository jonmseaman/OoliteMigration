# Contract: `component_census`

One program among the C++ component tests. It tries every ship definition and every equipment item in the
core data and gives each exactly one outcome. The values are defined in
[data-model.md](../data-model.md).

## Arguments

| Argument | Meaning |
|---|---|
| *(none)* | parent mode: run the whole census |
| `--seed <n>` | base seed; default 20260910 |
| `--only <kind>:<key>` | try one definition in this process and print its row |
| `--list` | print every definition with its class, try nothing |
| `--report <path>` | where to write the report; default `<build>/component/census-report.tsv` |
| `--expectations <path>` | default `tests/component-cpp/census-expectations.tsv` |
| `--data-overlay <dir>` | merge one fixture `shipdata.plist` after the core data (see *Proving it can fail*) |
| `--child --from <index> --progress <path>` | internal: child mode |

## How a run goes

1. The parent starts a child from index 0.
2. The child starts one headless game, lists the definitions in sorted order and, for each from
   its start index: writes the index and key to the progress file and flushes; reseeds from the
   base seed and the key; tries the definition; appends its row.
3. The child stops early, with a distinct exit code, when a definition leaves the universe
   unclean. It records that definition as `failed` first.
4. If the child exits with any other nonzero code, or is killed, the parent reads the progress
   file, records the definition being tried as `failed` with the evidence "child exited <code>"
   and the tail of the child's output, and starts a new child at the next index.
5. When the last index is done the parent sorts the rows, writes the report, applies the
   expectations file and prints a summary.

A child that has restarted more than 50 times stops the run with an error. That bounds a census
in which everything crashes.

## Output

- The report file, one row per definition.
- On standard output: one line per `failed` definition with its evidence, then a summary line:

```text
component_census: 194 ships, 41 equipment: P passed, L left, N not-applicable, F failed, X expected
```

## Exit codes

| Code | Meaning |
|---|---|
| 0 | every definition has an outcome, the count equals the data's, and every `failed` or `left` is listed in the expectations file with the same expectation |
| 1 | at least one unexpected outcome: an unlisted failure, or a listed definition that did not behave as listed |
| 2 | the census itself is unsound: no definitions found, a count mismatch, a key in the expectations file that is not in the data, an empty reason, too many restarts, or bad arguments |

Code 2 is what stops a census from passing while trying nothing (FR-020).

## Meson

Registered as `test('census', component_census, suite: 'component', timeout: 600, is_parallel: true)`.

## Proving it can fail

`component_census --data-overlay <dir>` reads one extra `shipdata.plist` from a directory of test
fixtures under `tests/component-cpp/fixtures/`, merged after the core data. The fixture holds one definition
with a model that does not exist. The acceptance check runs the census with the overlay and
requires exit 1 with that key, and only that key, reported as an unexpected failure.

The overlay directory is a fixture written for this test. It is not expansion content.
