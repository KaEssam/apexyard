# Handbook: Database Design — Transactions, Pooling & Pagination

**Scope:** PRs touching repository/query handlers (`**/*.cs`), `DbContext` configuration, connection-string/pooling setup, paginated API endpoints.
**Enforcement:** advisory.

## The rule

- **Isolation level: leave it at `Read Committed`** (the EF Core / SQL Server default) unless a specific race condition requires more, and say so in a comment. Never drop to `Read Uncommitted` to "fix" performance — that just permits dirty reads.
- **Connection pooling:** rely on the provider's built-in pool; never set `Pooling=false` in an app config. Never open/close a raw `SqlConnection`/`NpgsqlConnection` per row inside a loop — let `DbContext` (EF Core) or `IDbConnection` (Dapper) own the connection for the unit of work.
- **Pagination: keyset (seek) by default** on any large or unboundedly-growing table.
  Bad: `.Skip((page - 1) * pageSize).Take(pageSize)` on an `Orders`/`Events`/`AuditLog` table
  Good: `.Where(o => o.Id > lastId).OrderBy(o => o.Id).Take(pageSize)` with an index on the ordering column(s)
  `OFFSET/FETCH` is acceptable only for small, bounded tables or a UI that genuinely needs "jump to page N" (e.g. an internal admin grid).
- **One transaction per unit of work.** Never call `SaveChanges()` inside a loop (see @.claude/rules/dotnet.md).

## Why

`OFFSET N` pagination gets linearly slower as `N` grows — the database still scans and discards the first `N` rows on every request, so a cheap query degrades into a near-full scan as users page deeper. Keyset pagination seeks directly through the index and stays roughly constant-time regardless of depth — and it's stable under concurrent inserts, where offset pagination can skip or repeat rows. Raising isolation level indiscriminately adds lock contention and deadlock risk for a guarantee most endpoints don't need; lowering it reintroduces dirty reads silently. Misconfigured pooling (or connections opened per-row) exhausts the database's connection limit under load — an outage that only appears at production scale, never in local dev.

## What Rex flags

1. An API endpoint or repository implementing paged/"load more"/infinite-scroll access via `Skip(n).Take(m)` (or SQL `OFFSET`) against a table with no bounded row count (events, orders, logs, audit, messages).
2. `IsolationLevel.Serializable` or `IsolationLevel.RepeatableRead` set on a transaction with no comment naming the anomaly it prevents.
3. `IsolationLevel.ReadUncommitted` used anywhere.
4. `Pooling=false` (or equivalent) in a connection string, or a raw connection opened inside a loop instead of once per unit of work.
5. `SaveChanges()` invoked inside a `foreach`/`for` loop.

## Sample finding

> `Api/Controllers/OrdersController.cs:71` — `GetOrders(int page, int pageSize)` uses `.Skip((page - 1) * pageSize).Take(pageSize)` against `Orders` (unbounded growth). Switch to keyset pagination: accept a `lastOrderId` cursor and `.Where(o => o.Id > lastOrderId).OrderBy(o => o.Id).Take(pageSize)`.

## What's NOT a violation

- `OFFSET/FETCH` on a small, bounded reference table or an internal admin screen with an explicit "jump to page N" requirement.
- An elevated isolation level with a comment/AgDR reference naming the race it guards (e.g. inventory reservation).
- Connection pooling left at provider defaults — the common, correct case; nothing to flag.
- A single `SaveChanges()` call after accumulating multiple tracked changes in a loop — only calling it *per iteration* is the violation.

Extends @.claude/rules/dotnet.md § "Async" (CancellationToken chain) and § "Data Access — EF Core + Dapper".

---

*Part of [ApexYard](https://github.com/me2resh/apexyard) — multi-project SDLC framework for Claude Code · MIT.*
