# PrefixedIdDemo

Phoenix spike for `ash_prefixed_id` across current Ash ecosystem packages:

- Ash `3.26.0`
- AshPostgres `2.9.1`
- AshGraphQL `1.9.4`
- AshJsonApi `1.6.6`
- AshTypescript `0.17.3`
- AshPhoenix `2.3.22`

## What It Proves

- `Team`, `Project`, and `Todo` are Ash resources backed by Postgres.
- IDs render as `team_*`, `proj_*`, and `todo_*`.
- Postgres stores native `uuid` columns and foreign keys.
- Primary keys default to `uuid_generate_v7()` in generated migrations.
- GraphQL, JSON:API, AshTypescript RPC, and LiveView all use the same resources.

## Run Locally

Start an isolated Postgres cluster on port `55432`:

```sh
initdb -D /tmp/ash_prefixed_id_pg --no-locale --encoding=UTF8
pg_ctl -D /tmp/ash_prefixed_id_pg -l /tmp/ash_prefixed_id_pg.log -o "-p 55432 -k /tmp" start
```

Set up and run the app:

```sh
mix deps.get
PGPORT=55432 mix ecto.setup
PORT=4107 PGPORT=55432 mix phx.server
```

Open:

- LiveView: http://localhost:4107
- GraphQL playground: http://localhost:4107/gql/playground
- JSON:API todos: http://localhost:4107/api/json/catalog/todos

## Smoke Checks

GraphQL nested relationship IDs:

```sh
curl -X POST http://localhost:4107/gql \
  -H 'content-type: application/json' \
  --data '{"query":"{ listTodos { id title projectId project { id name teamId team { id name } } } }"}'
```

JSON:API create with a prefixed foreign key:

```sh
PROJECT_ID=$(curl -fsS http://localhost:4107/api/json/catalog/projects -H 'accept: application/vnd.api+json' | ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch("data").first.fetch("id")')

curl -X POST http://localhost:4107/api/json/catalog/todos \
  -H 'accept: application/vnd.api+json' \
  -H 'content-type: application/vnd.api+json' \
  --data "{\"data\":{\"type\":\"todo\",\"attributes\":{\"title\":\"Created through JSON API\",\"project_id\":\"$PROJECT_ID\"}}}"
```

AshTypescript generated client from Node:

```sh
node --experimental-strip-types --input-type=module -e 'import { listTodos } from "./assets/js/ash_rpc.ts"; const customFetch = (input, init) => fetch(new URL(input, "http://localhost:4107"), init); console.log(await listTodos({ fields: ["id", "title", "projectId", { project: ["id", "teamId", { team: ["id", "name"] }] }], customFetch }));'
```

Postgres storage check:

```sh
psql -h localhost -p 55432 -d prefixed_id_demo_dev -Atc "select table_name, column_name, data_type, column_default from information_schema.columns where table_name in ('teams','projects','todos') and column_name in ('id','team_id','project_id') order by table_name, ordinal_position;"
```
