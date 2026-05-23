# AshPrefixedId

An [Ash](https://ash-hq.org/) extension for working with prefixed IDs (e.g. `user_CWzLBdFy2f1XhrtesFferY`).

Inspired by [Stripe's object IDs](https://dev.to/stripe/designing-apis-for-humans-object-ids-3o5a), this library lets you use human-readable, prefixed identifiers while storing standard UUIDs in the database.

## Installation

Add `ash_prefixed_id` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_prefixed_id, "~> 0.2.0"}
  ]
end
```

## Usage

Add the `AshPrefixedId` extension to your resource and configure a prefix:

```elixir
defmodule App.Blog.Post do
  use Ash.Resource,
    domain: App.Blog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "post"
  end

  actions do
    defaults [:read, :destroy, create: [:title], update: [:title]]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end
end
```

Prefixes are validated at compile time. They must use lowercase ASCII letters
and underscores, start and end with a letter, and be no longer than 63
characters.

Primary keys must use `uuid_primary_key` or `uuid_v7_primary_key`.

If a resource has been renamed, keep accepting older external IDs with
`legacy_prefixes`:

```elixir
prefixed_id do
  prefix "account"
  legacy_prefixes ["user"]
end
```

New records generate `account_...` IDs. Existing `user_...` IDs still cast and
resolve to the same resource.

```elixir
Post
|> Ash.Changeset.for_create(:create, %{title: "Hello world"})
|> Ash.create!()
#=> %Post{id: "post_CWzLBdFy2f1XhrtesFferY"}
```

### Foreign Keys

`belongs_to` relationships automatically get the correct prefixed ID type:

```elixir
relationships do
  belongs_to :post, App.Blog.Post
  # post_id is auto-created as App.Blog.Post.ObjectId
end
```

### AnyPrefixedId

Register `AnyPrefixedId` as a custom type to accept prefixed IDs anywhere `:uuid` is used:

```elixir
config :ash, custom_types: [uuid: AshPrefixedId.AnyPrefixedId]
```

### PostgreSQL UUIDv7

Enable server-side UUIDv7 generation with `AshPrefixedId.PostgresExtension`:

```elixir
defmodule MyApp.Repo do
  use AshPostgres.Repo, otp_app: :my_app

  def installed_extensions do
    ["uuid-ossp", "citext", AshPrefixedId.PostgresExtension]
  end
end
```

Then in your resource:

```elixir
prefixed_id do
  prefix "post"
  migration_default? true
end
```

On PostgreSQL 18+, use the native `uuidv7()` function instead:

```elixir
prefixed_id do
  prefix "post"
  migration_default? true
  migration_default_function "uuidv7()"
end
```

`migration_default_function` must be a zero-arity PostgreSQL function name, for
example `uuidv7()` or `extensions.uuidv7()`.

### API Integrations

Generated ObjectId types expose prefixed IDs as GraphQL `ID` values and
AshTypescript `string` values. Database storage remains native `uuid`; API
clients see values like `post_CWzLBdFy2f1XhrtesFferY`.

For stricter TypeScript clients, opt into branded strings per resource:

```elixir
prefixed_id do
  prefix "account"
  typescript_brand? true
end
```

AshTypescript will see `string & { readonly __prefix: "account" }` for that
ObjectId type.

Phoenix routes can also use prefixed IDs directly:

```elixir
prefixed_id do
  prefix "account"
  phoenix_param? true
end
```

When Phoenix is available, this implements `Phoenix.Param` for the resource and
returns the prefixed primary key from route helpers.
If `phoenix_param?` is enabled, `Phoenix.Param` must be available when the
resource compiles.

See `examples/prefixed_id_demo` for a Phoenix/AshPostgres spike with GraphQL,
JSON:API, AshTypescript RPC, and LiveView.

## Guides

- [Getting Started](guides/getting-started.md): add the extension to a resource and create relationships.
- [PostgreSQL UUIDv7](guides/postgres-uuidv7.md): install database-side UUIDv7 generation and use PostgreSQL 18 native `uuidv7()`.
- [Legacy Prefixes](guides/legacy-prefixes.md): rename prefixes without breaking old IDs.
- [API Integrations](guides/api-integrations.md): GraphQL, JSON:API, AshTypescript, and Phoenix routes.
- [Global Lookup](guides/global-lookup.md): resolve prefixed IDs against an explicit domain allowlist.
- [Data Layer Support](guides/data-layer-support.md): what is portable, what is Postgres-only, and how to configure AshSqlite.

### Utility Functions

```elixir
# Parse a prefixed ID into structured parts
AshPrefixedId.parse("user_CWzLBdFy2f1XhrtesFferY")
#=> {:ok, %AshPrefixedId.ParsedId{prefix: "user", uuid: "5d446d08-df6a-404d-a1e5-decc78429b3d", ...}}

# Check or extract a prefix
AshPrefixedId.valid?("user_CWzLBdFy2f1XhrtesFferY")
AshPrefixedId.prefix("user_CWzLBdFy2f1XhrtesFferY")
#=> {:ok, "user"}

# Decode a prefixed ID to a UUID string
AshPrefixedId.decode_object_id("user_CWzLBdFy2f1XhrtesFferY")
#=> {:ok, "5d446d08-df6a-404d-a1e5-decc78429b3d"}

# Convert to raw UUID binary (for SQL fragments)
AshPrefixedId.to_uuid!("user_CWzLBdFy2f1XhrtesFferY")

# Convert UUID back to prefixed ID
AshPrefixedId.to_prefixed_id(uuid_binary, "user")

# Find which resource a prefixed ID belongs to
AshPrefixedId.find_resource_for_id(domains, "user_CWzLBdFy2f1XhrtesFferY")

# Resolve or fetch globally by prefixed ID from an allowed domain list
AshPrefixedId.resource(domains, "user_CWzLBdFy2f1XhrtesFferY")
#=> {:ok, MyApp.Accounts.User}

AshPrefixedId.get(domains, "user_CWzLBdFy2f1XhrtesFferY", actor: current_user, authorize?: true)
#=> {:ok, %MyApp.Accounts.User{}}

# Return a resource's primary and legacy prefixes
AshPrefixedId.prefixes_for_resource(MyApp.Accounts.User)
#=> ["account", "user"]

# Detect duplicate prefixes across domains
AshPrefixedId.find_duplicate_prefixes(domains)
```

For more detailed information, read the `AshPrefixedId` moduledoc.

## Acknowledgments

This project is a fork of [ash_object_ids](https://github.com/drtheuns/ash_object_ids) by [Randall Theuns](https://github.com/drtheuns). The original work laid the foundation for prefixed ID support in Ash.

## License

MIT — see [LICENSE](LICENSE) for details.
