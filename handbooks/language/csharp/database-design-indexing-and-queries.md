# Handbook: Database Design — Indexing & Sargable Queries

**Scope:** PRs touching `**/*.sql`, EF Core migrations/configurations, LINQ queries in `**/*.cs`, Dapper raw SQL strings.
**Enforcement:** advisory.

## The rule

- **Composite index column order = query order.** Equality-predicate columns first, then range/sort columns — the index should mirror the `WHERE`/`ORDER BY` it serves.
- **Covering indexes (`INCLUDE`)** only on a measured hot read path, to avoid key lookups — not added preemptively "just in case."
- **Filtered indexes** for queries hitting a small, stable, highly-selective subset of a large table (`WHERE IsDeleted = 0`, `WHERE Status = 'Active'`).
- **Don't over-index.** Every index taxes every `INSERT`/`UPDATE`/`DELETE`. Each new index needs a query it serves, stated in the PR.
- **Sargable predicates only** — never wrap an indexed column in a function/expression in `WHERE`.
  Bad: `.Where(x => x.CreatedAt.Year == 2026)` / `WHERE YEAR(CreatedAt) = 2026`
  Good: `.Where(x => x.CreatedAt >= start && x.CreatedAt < end)` / `WHERE CreatedAt >= @start AND CreatedAt < @end`
- **Never `SELECT *`.** EF Core: project into a DTO with `.Select(...)`. Dapper: name columns explicitly.

## Why

A non-sargable predicate forces SQL Server/PostgreSQL to evaluate the function per row before it can compare — the optimizer can't seek the index even when one exists, so it falls back to a scan. Over-indexing silently taxes every write with extra B-tree maintenance that never shows up until the table's write volume grows. `SELECT *` couples the query to the full row shape (breaks on the next column add/rename), pulls unneeded bytes over the wire, and defeats any covering index that was built for a narrower shape.

## What Rex flags

1. A LINQ predicate applying a function/computation to a mapped column: `.Where(x => x.CreatedAt.Year == y)`, `.Where(x => x.Email.ToUpper() == v)`.
2. Raw SQL (migration or Dapper string) with `WHERE <FUNC>(<indexed_column>)`.
3. `SELECT *` (or `SELECT TOP N *`) in any `.sql` file or Dapper query string.
4. An EF Core query returning full tracked entities into a handler/controller that reads only 1–2 properties from the result — should project.
5. A new index added in a migration with no comment/PR description of the query it serves, on a table already carrying several non-PK indexes.
6. A composite index whose column order visibly doesn't follow equality-then-range for the query it's named after.

## Sample finding

> `Repositories/OrderRepository.cs:58` — `.Where(o => o.CreatedAt.Year == year)` is not sargable; SQL Server can't seek `IX_Order_CreatedAt` and scans instead. Rewrite as `.Where(o => o.CreatedAt >= start && o.CreatedAt < end)`.

## What's NOT a violation

- A function wrapping the *literal/parameter* side, not the column (`WHERE Col = UPPER(@param)`) — only the indexed side matters.
- `SELECT *` in ad-hoc debugging scripts that aren't part of the shipped application code.
- A covering index added with a benchmark/profiling note naming the query it targets.
- A filtered index's write-maintenance overhead, accepted deliberately for a documented hot-read table.

Extends @.claude/rules/dotnet.md § "Data Access — EF Core + Dapper" (`AsNoTracking()` for reads; Dapper for measurably slow heavy queries).

---

*Part of [ApexYard](https://github.com/me2resh/apexyard) — multi-project SDLC framework for Claude Code · MIT.*
