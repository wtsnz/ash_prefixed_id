# Legacy Prefixes

<!-- read_when: You are renaming a resource, changing an external API prefix, or accepting old IDs from existing clients. -->

Use `legacy_prefixes` when the public prefix for a resource needs to change
without breaking old clients.

## Configure A New Prefix

```elixir
defmodule MyApp.Accounts.Account do
  use Ash.Resource,
    domain: MyApp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "account"
    legacy_prefixes ["user"]
  end

  attributes do
    uuid_v7_primary_key :id
  end
end
```

New records generate IDs like:

```text
account_CWzLBdFy2f1XhrtesFferY
```

Incoming old IDs are still accepted:

```text
user_CWzLBdFy2f1XhrtesFferY
```

The generated ObjectId type canonicalizes accepted legacy IDs back to the
primary prefix at the Ash type boundary.

## Resource Lookup

Legacy prefixes participate in prefix-to-resource lookup:

```elixir
AshPrefixedId.resource([MyApp.Accounts], "user_CWzLBdFy2f1XhrtesFferY")
#=> {:ok, MyApp.Accounts.Account}
```

You can inspect all accepted prefixes for a resource:

```elixir
AshPrefixedId.prefixes_for_resource(MyApp.Accounts.Account)
#=> ["account", "user"]
```

## Duplicate Prefixes

The current prefix and legacy prefixes must be unique within a resource:

```elixir
prefixed_id do
  prefix "account"
  legacy_prefixes ["account"]
end
```

That raises a DSL error.

Duplicate prefixes across different resources are allowed at compile time
because applications may intentionally expose different bounded contexts.
Use `find_duplicate_prefixes/1` to audit a domain allowlist:

```elixir
AshPrefixedId.find_duplicate_prefixes([MyApp.Accounts, MyApp.Billing])
```

Global lookup helpers return an ambiguity error when a prefix maps to more than
one resource in the supplied allowlist.

## Operational Advice

Keep legacy prefixes as long as old clients, webhooks, exports, URLs, or audit
logs may send them back to the application. Removing a legacy prefix is a public
API break.

If you need to deprecate a prefix, log usage at API boundaries before removing
it.
