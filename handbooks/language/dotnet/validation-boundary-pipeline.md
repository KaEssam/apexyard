# Handbook: Input Validation at the API Boundary

**Scope:** PRs touching `**/Application/**/Commands/**`, `**/Application/**/Queries/**`, `**/Api/Controllers/**`, `**/Behaviors/**`.
**Enforcement:** advisory.

## The rule

- Every command has exactly one `AbstractValidator<TCommand>`, colocated with it (`CreateOrderCommand.cs` + `CreateOrderCommandValidator.cs`).
- Validation runs as a MediatR `IPipelineBehavior<TRequest, TResponse>` registered once in DI — never invoked manually inside a handler or controller.
- Queries get a validator only when they carry user-supplied filters/paging that can be malformed; simple lookups by a typed ID don't need one.
- Controllers contain zero manual `if (...) return BadRequest(...)` shape checks — that belongs to the validator.
- Never trust client-supplied `UserId`, `Role`, `IsAdmin`, or price/amount fields — re-derive authorization and server-owned values from the authenticated principal, not the request body.

Bad:

```csharp
[HttpPost]
public async Task<IActionResult> Create(CreateOrderRequest req)
{
    if (req.Quantity <= 0) return BadRequest("Quantity must be positive");
    var result = await _sender.Send(new CreateOrderCommand(req.Quantity, req.CustomerEmail));
    return Ok(result);
}
```

Good:

```csharp
public sealed class CreateOrderCommandValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderCommandValidator()
    {
        RuleFor(x => x.Quantity).GreaterThan(0);
        RuleFor(x => x.CustomerEmail).NotEmpty().EmailAddress();
    }
}

[HttpPost]
public async Task<IActionResult> Create(CreateOrderCommand command, CancellationToken ct)
    => (await _sender.Send(command, ct)).ToActionResult();
```

## Why

Manual checks scattered across controllers drift out of sync and are invisible to a reviewer scanning for validation coverage. A missing validator on one command is a silent hole an attacker finds by fuzzing that endpoint. A pipeline behavior makes "every command is validated" a structural guarantee instead of a per-controller habit — see `@.claude/rules/dotnet.md` § CQRS via MediatR.

## What Rex flags

1. A command/request record with no matching `AbstractValidator<T>` in the same folder or namespace.
2. Manual null/range/format checks inside a controller action or a handler's `Handle()` method.
3. Validators registered nowhere in DI (no `AddValidatorsFromAssembly`/equivalent) despite validator classes existing in the project.
4. Client-supplied `UserId`/`OwnerId`/`Role`/`IsAdmin` bound straight from the request body and used without re-derivation from `ClaimsPrincipal`.

## Sample finding

> `OrderController.cs:42` — `Create` manually checks `req.Quantity <= 0` instead of relying on `CreateOrderCommandValidator`; if this inline check is ever deleted, invalid quantities reach the handler unvalidated.

## What's NOT a violation

- Simple GET queries with no user-supplied filters — no validator needed.
- Guard clauses inside domain entities/value objects (invariants, not input shape) — see `validation-domain-invariants.md`.
- A validator with an async `MustAsync` uniqueness check against a repository — still one validator per command.
