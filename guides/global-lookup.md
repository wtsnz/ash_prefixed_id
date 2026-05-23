# Global Lookup

<!-- read_when: You need to accept an arbitrary prefixed ID and resolve it to the correct Ash resource or record. -->

Global lookup is useful at boundaries where callers can send IDs for more than
one resource type:

- admin search boxes
- webhook payloads
- audit log viewers
- background jobs
- support tooling

`AshPrefixedId` resolves IDs against an explicit domain allowlist.

## Resolve A Resource

```elixir
domains = [MyApp.Accounts, MyApp.Blog, MyApp.Billing]

AshPrefixedId.resource(domains, "post_CWzLBdFy2f1XhrtesFferY")
#=> {:ok, MyApp.Blog.Post}
```

`resource/2` returns explicit errors:

```elixir
{:error, {:invalid_id, :missing_separator}}
{:error, :unknown_prefix}
{:error, {:ambiguous_prefix, "user", [MyApp.Accounts.User, MyApp.Legacy.User]}}
```

Use `resource!/2` when raising is appropriate.

## Fetch A Record

```elixir
AshPrefixedId.get(domains, "post_CWzLBdFy2f1XhrtesFferY")
#=> {:ok, %MyApp.Blog.Post{}}
```

Options are passed to `Ash.get/3`:

```elixir
AshPrefixedId.get(
  domains,
  "post_CWzLBdFy2f1XhrtesFferY",
  actor: current_user,
  tenant: tenant,
  authorize?: true
)
```

Use `get!/3` when raising is appropriate.

## Security Model

Global lookup is deliberately not application-global. Always pass the domains
that are safe for the current boundary.

For example, a public webhook endpoint might allow:

```elixir
[MyApp.Billing]
```

while an admin panel might allow:

```elixir
[MyApp.Accounts, MyApp.Billing, MyApp.Support]
```

Authorization still belongs to Ash. Pass `actor`, `tenant`, and `authorize?`
options to `get/3` when records need policy enforcement.

## Prefix Maps

You can inspect prefix mappings:

```elixir
AshPrefixedId.map_prefixes_to_resources(domains)
#=> %{"post" => [MyApp.Blog.Post], "user" => [MyApp.Accounts.User]}
```

Detect duplicates:

```elixir
AshPrefixedId.find_duplicate_prefixes(domains)
```

Duplicate prefixes are not automatically invalid across domains. Different
bounded contexts may intentionally use the same prefix. The lookup functions
surface ambiguity when it matters.
