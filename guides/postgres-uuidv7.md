# PostgreSQL UUIDv7

<!-- read_when: You are using AshPostgres, generated migrations, database-side UUID defaults, or PostgreSQL 18 native uuidv7(). -->

`AshPrefixedId` works without database-side UUID generation because Ash can
generate IDs in the application. Database defaults are useful when records may
be inserted outside Ash, for example through SQL scripts, ETL jobs, or manual
seeds.

## Bundled UUIDv7 Function

For PostgreSQL versions before 18, install `AshPrefixedId.PostgresExtension` in
your AshPostgres repo:

```elixir
defmodule MyApp.Repo do
  use AshPostgres.Repo, otp_app: :my_app

  def installed_extensions do
    ["ash-functions", AshPrefixedId.PostgresExtension]
  end
end
```

Then enable migration defaults on the resource:

```elixir
prefixed_id do
  prefix "post"
  migration_default? true
end
```

Run codegen and migrations:

```sh
mix ash.codegen add_prefixed_ids
mix ash.migrate
```

Generated migrations use:

```elixir
default: fragment("uuid_generate_v7()")
```

The database column remains `uuid`.

## PostgreSQL 18 Native uuidv7()

PostgreSQL 18 includes a native `uuidv7()` function. If your database provides
that function, configure the resource directly:

```elixir
prefixed_id do
  prefix "post"
  migration_default? true
  migration_default_function "uuidv7()"
end
```

If the function lives in a schema, include the schema:

```elixir
prefixed_id do
  prefix "post"
  migration_default? true
  migration_default_function "extensions.uuidv7()"
end
```

`migration_default_function` must be a zero-arity PostgreSQL function name.
Arbitrary SQL fragments are rejected.

## When Not To Use migration_default?

Do not enable `migration_default?` for non-Postgres data layers. The option is
implemented through AshPostgres migration defaults and expects PostgreSQL
function syntax.

You also do not need it if all records are created through Ash and application
generated UUIDv7 values are enough for your system.

## Timestamp Extraction

`AshPrefixedId.PostgresExtension` also installs:

```sql
timestamp_from_uuid_v7(uuid)
```

The function is intentionally not marked `LEAKPROOF`, because that requires
PostgreSQL superuser privileges and breaks common managed Postgres providers.
Applications that rely on RLS or security-barrier views can mark it leakproof
manually as a privileged database operation.
