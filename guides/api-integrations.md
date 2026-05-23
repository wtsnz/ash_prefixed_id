# API Integrations

<!-- read_when: You are exposing prefixed IDs through AshGraphQL, AshJsonApi, AshTypescript, Phoenix routes, or client APIs. -->

Generated ObjectId types are regular Ash types, so the same resource definition
can be exposed through multiple Ash API packages.

## GraphQL

ObjectId types expose GraphQL fields and inputs as `:id`.

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPrefixedId, AshGraphql.Resource]

  prefixed_id do
    prefix "post"
  end

  graphql do
    type :post
  end
end
```

GraphQL clients see prefixed strings:

```graphql
{
  listPosts {
    id
    title
  }
}
```

```json
{
  "id": "post_CWzLBdFy2f1XhrtesFferY",
  "title": "Hello world"
}
```

## JSON:API

AshJsonApi works with the same resource type. Public IDs and relationship IDs
remain prefixed at the API boundary while the data layer stores UUIDs.

```json
{
  "data": {
    "type": "comment",
    "attributes": {
      "body": "Nice post",
      "post_id": "post_CWzLBdFy2f1XhrtesFferY"
    }
  }
}
```

## AshTypescript

By default, generated TypeScript types use `string`:

```ts
type Post = {
  id: string;
};
```

For stricter clients, enable branded strings:

```elixir
prefixed_id do
  prefix "post"
  typescript_brand? true
end
```

With legacy prefixes:

```elixir
prefixed_id do
  prefix "account"
  legacy_prefixes ["user"]
  typescript_brand? true
end
```

AshTypescript sees:

```ts
string & { readonly __prefix: "account" | "user" }
```

This is still a runtime string. The brand helps TypeScript catch accidental
mixing of IDs from different resources.

## Phoenix Routes

Enable `Phoenix.Param` generation when route helpers should emit prefixed IDs:

```elixir
prefixed_id do
  prefix "post"
  phoenix_param? true
end
```

Then:

```elixir
~p"/posts/#{post}"
```

renders:

```text
/posts/post_CWzLBdFy2f1XhrtesFferY
```

`Phoenix.Param` must be available at resource compile time. If Phoenix is an
optional dependency in a shared library, keep `phoenix_param?` disabled in that
library and implement route params in the Phoenix application instead.

## Example App

See `examples/prefixed_id_demo` for a Phoenix app that exercises:

- AshPostgres storage
- GraphQL
- JSON:API
- AshTypescript RPC
- Phoenix LiveView
- `Phoenix.Param`
- legacy prefixes
