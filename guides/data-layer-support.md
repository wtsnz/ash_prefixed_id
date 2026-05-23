# Data Layer Support

<!-- read_when: You are deciding whether AshPrefixedId works with AshPostgres, AshSqlite, ETS, or another Ash data layer. -->

The core `AshPrefixedId` type is not Postgres-specific. The generated ObjectId
type stores as `:uuid`, casts prefixed input, dumps to a native UUID value, and
renders stored UUIDs back with the resource prefix.

## Verified Today

The repository currently verifies:

- `Ash.DataLayer.Ets` in the root test suite
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

AshSqlite should be a good candidate for the core ObjectId behavior because the
extension operates at the Ash type boundary. It is not currently certified by a
dedicated regression app in this repository.

Before claiming official AshSqlite support, add a small test app or support
resource that proves:

- primary key generation
- create/read/update/destroy
- `belongs_to` foreign keys
- legacy prefix primary-key lookup
- generated migrations do not rely on Postgres-only defaults

## Practical Recommendation

For applications today:

- Use the core extension with any data layer that handles Ash UUID types.
- Use `migration_default?` only with AshPostgres.
- Treat AshSqlite support as expected but not yet documented as verified.
