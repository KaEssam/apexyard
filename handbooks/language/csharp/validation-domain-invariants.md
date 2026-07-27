# Handbook: Guard Clauses, Value Objects, and Result vs Exceptions

**Scope:** PRs touching `**/Domain/**`, `**/Application/**/Commands/**`, `**/Application/**/Handlers/**`.
**Enforcement:** advisory.

## The rule

- **Value objects** wrap constrained primitives (email, money, percentage, phone) so an invalid instance can never exist — validate once, in the factory, not everywhere the primitive is used.
- **Guard clauses** enforce domain invariants inside entities (an `Order` can't ship twice) — this is distinct from FluentValidation, which enforces *input shape* at the boundary.
- **Input validation** (is this field present / well-formed / in range?) belongs in the command validator. **Business-rule checks** (is this order allowed to ship given current inventory?) belong in the domain/handler.
- Expected, recoverable failures → `Result<T>.Failure(...)`. Truly exceptional/programmer-error states → guard clause throws, per `@.claude/rules/dotnet.md` § Error Handling.

Bad — `CustomerEmail` is a bare `string`; "is this valid" gets re-checked in the validator, the handler, and a report generator.

Good — value object validates once, entity guard clause protects the invariant:

```csharp
public sealed record Email
{
    public string Value { get; }
    private Email(string value) => Value = value;

    public static Result<Email> Create(string value)
        => string.IsNullOrWhiteSpace(value) || !value.Contains('@')
            ? Result<Email>.Failure("Email is not valid")
            : Result<Email>.Success(new Email(value));
}

public sealed class Order
{
    public void AddLine(OrderLine line)
    {
        if (Status != OrderStatus.Draft)
            throw new InvalidOperationException("Cannot add lines to a non-draft order");
        _lines.Add(line);
    }
}
```

## Why

Primitive obsession means every consumer re-derives "what makes an email valid" and eventually disagrees. Throwing for *expected* validation failures (duplicate SKU, over-limit quantity) turns normal request handling into exception-driven control flow — slow, and it hides the failure path from the method signature. Conflating input validation with business rules pushes DB-dependent checks into the validator, coupling it to infrastructure it shouldn't need.

## What Rex flags

1. A domain concept (email, money, percentage) represented as a bare `string`/`decimal` in more than one place with duplicated validation logic.
2. `throw new Exception(...)` used for an expected validation failure a `Result<T>` could carry instead.
3. A FluentValidation rule that queries a repository/DbContext for a **business** condition (order exists and is shippable) rather than an **input-shape** condition (ID is a valid GUID).
4. An entity mutator method with no guard clause protecting its invariant.

## Sample finding

> `Order.cs:88` — `MarkAsShipped()` sets `Status = OrderStatus.Shipped` with no guard against a `Cancelled` order; add a guard clause and have the caller return `Result.Failure` instead of allowing a silent invalid transition.

## What's NOT a violation

- A cheap `MustAsync` existence/uniqueness check that's clearly input-shape — judgment call; flag only when it encodes multi-step business logic.
- Throwing for genuinely unexpected states (an enum value outside its known range from corrupted data).
- Plain wire-transport DTOs with no behavior — value-object wrapping applies to domain types, not DTOs.
