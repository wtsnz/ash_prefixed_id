# Data Layer Support

<!-- read_when: You are deciding whether AshPrefixedId works with AshPostgres, AshSqlite, ETS, or another Ash data layer. -->

The core `AshPrefixedId` type is not Postgres-specific. The generated ObjectId
type stores as `:uuid`, casts prefixed input, dumps to a native UUID value, and
renders stored UUIDs back with the resource prefix.

## Verified Today

The repository currently verifies:

- `Ash.DataLayer.Ets` in the root test suite
- `AshSqlite.DataLayer` in the root test suite with binary UUID storage
- `AshPostgres.DataLayer` in the Phoenix example app
- AshPostgres migration defaults and extension snapshots

## Expected Portable Behavior

These features should be data-layer portable when the data layer supports Ash
UUID storage:

- generated ObjectId primary keys
- prefixed ID casting
- stored UUID rendering
- `belongs_to` foreign key type rewriting
- legacy prefix casting and primary-key lookup
- parsing helpers
- resource prefix lookup
- GraphQL, JSON:API, and AshTypescript type exposure
- `Phoenix.Param`

## Postgres-Only Behavior

These features are AshPostgres-specific:

- `AshPrefixedId.PostgresExtension`
- `migration_default?`
- `migration_default_function`
- generated migration defaults using `fragment("uuid_generate_v7()")`
- generated migration defaults using PostgreSQL 18 `uuidv7()`

Do not enable `migration_default?` for AshSqlite or other non-Postgres data
layers unless that data layer explicitly supports compatible migration defaults.

## AshSqlite

AshSqlite is verified for the core ObjectId behavior when Ecto SQLite is
configured for binary UUID storage:

```elixir
config :ecto_sqlite3, :uuid_type, :binary
```

Set this before generating SQLite migrations so `:uuid` columns are generated as
`BLOB` columns. The repository regression test stores and reads raw 16-byte UUID
values while Ash resources expose prefixed IDs.

The AshSqlite coverage proves:

- primary key generation
- create/read/update/destroy
- `belongs_to` foreign keys
- legacy prefix primary-key lookup
- global lookup through `AshPrefixedId.get/3`

Ecto SQLite's default UUID mode is string-based. Keep binary UUID mode if your
requirement is that database rows remain unprefixed UUID values.

## Practical Recommendation

For applications today:

- Use the core extension with any data layer that handles Ash UUID types.
- Use `migration_default?` only with AshPostgres.
- Use AshSqlite with `config :ecto_sqlite3, :uuid_type, :binary` when you need
  raw UUID storage.
