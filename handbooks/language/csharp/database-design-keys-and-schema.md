# Handbook: Database Design — Keys, Schema & Naming

**Scope:** PRs touching `**/Migrations/**`, `**/*.sql`, EF Core entity classes/configurations (`**/Entities/**`, `**/Configurations/**`, `OnModelCreating`).
**Enforcement:** advisory.

## The rule

- **Surrogate keys by default.** PK is a surrogate (`int`/`bigint` identity or `Guid`), never a mutable business column.
  Bad: `public string Email { get; set; } = null!; // PK`
  Good: `public int Id { get; set; }` (PK) + `HasIndex(x => x.Email).IsUnique()`
- **`Guid` vs `int`/`bigint`:** prefer `bigint identity` for high-insert hot tables (fewer page splits than a random `Guid` clustered key). If a `Guid` PK is required (client-generated IDs, cross-DB merge), use a sequential generator (`Guid.CreateVersion7()` on .NET 9+/EF Core, or `NEWSEQUENTIALID()`), not `Guid.NewGuid()`.
- **Naming:** match C# PascalCase (EF Core's default convention) consistently — don't mix `snake_case` and `PascalCase` in the same schema. FK columns are `<Entity>Id`. Junction tables are `<EntityA><EntityB>`.
- **Normalize to 3NF by default.** Denormalize only for a measured read-hot path or a reporting/projection table, and say so in the PR or an AgDR.
- **Foreign keys always declare `OnDelete` explicitly** — never leave EF Core's default (`Cascade` for required relationships) unexamined.

## Why

A mutable natural key as PK forces every FK and every downstream join to churn whenever the business value changes (email edits, name changes). A random `Guid` clustered index causes constant page splits and fragmentation under write load — invisible in dev, painful at scale. Undeclared delete behavior is how a `DELETE` on a parent row silently cascades and wipes rows nobody meant to touch — a classic production data-loss incident.

## What Rex flags

1. New migration/entity declares the PK on a mutable business column (`Email`, `Username`, `Name`, `Phone`) instead of a surrogate `Id`.
2. `Guid` PK/FK added to a table the PR describes as high-insert-rate (payments, events, audit log) with no sequential-generation strategy mentioned.
3. A required FK relationship configured via Fluent API or migration with no explicit `OnDelete(...)` call.
4. Naming convention mixed within one migration/entity file (a `snake_case` column beside PascalCase ones).
5. A new column/table duplicates data already owned by another table, with no comment or AgDR reference explaining the denormalization.

## Sample finding

> `Migrations/20260115120000_AddOrder.cs:34` — the FK targets `Customer.Email` instead of `Customer.Id`. Emails are mutable; add `CustomerId` (surrogate key) and, if uniqueness matters, a unique index on `Customer.Email` instead.

## What's NOT a violation

- Natural keys on true immutable lookup tables (`CountryCode`, `CurrencyCode`).
- `OnDelete(DeleteBehavior.Cascade)` explicitly chosen and justified for an owned/dependent entity (e.g. `OrderLine` belongs to `Order`).
- Denormalized tables clearly named `*ReadModel`/`*Projection` — deliberate CQRS read-side denormalization.
- `Guid` PK on a low-write reference/lookup table — fragmentation concern doesn't apply at that write volume.

Extends @.claude/rules/dotnet.md § "Data Access — EF Core + Dapper" (migrations: never modify existing migrations).

---

*Part of [ApexYard](https://github.com/me2resh/apexyard) — multi-project SDLC framework for Claude Code · MIT.*
