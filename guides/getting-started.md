# Getting Started

<!-- read_when: You are adding AshPrefixedId to a resource for the first time or checking the basic resource and relationship setup. -->

`AshPrefixedId` turns a UUID primary key into a resource-specific external ID
like `post_CWzLBdFy2f1XhrtesFferY`, while keeping the stored value as a native
UUID.

## Install

Add the dependency:

```elixir
def deps do
  [
    {:ash_prefixed_id, "~> 0.2.0"}
  ]
end
```

Then fetch dependencies:

```sh
mix deps.get
```

## Add The Extension

Add `AshPrefixedId` to the resource and configure a prefix:

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "post"
  end

  postgres do
    table "posts"
    repo MyApp.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:title], update: [:title]]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end
  end
end
```

Primary keys must use `uuid_primary_key` or `uuid_v7_primary_key`. Custom
UUID-like primary key types are rejected so the extension can guarantee correct
casting, dumping, and rendering behavior.

## Prefix Rules

Prefixes are validated at compile time. A prefix must:

- contain only lowercase ASCII letters and underscores
- start and end with a lowercase ASCII letter
- be no longer than 63 characters

Valid examples:

```elixir
prefix "user"
prefix "billing_account"
```

Invalid examples:

```elixir
prefix "User"
prefix "_user"
prefix "user_"
prefix "billing-account"
```

## Read And Create

The resource ID is generated as a prefixed string:

```elixir
post =
  MyApp.Blog.Post
  |> Ash.Changeset.for_create(:create, %{title: "Hello world"})
  |> Ash.create!()

post.id
#=> "post_CWzLBdFy2f1XhrtesFferY"
```

Stored UUIDs cast back to the resource prefix when records are read from the
data layer.

## Relationships

`belongs_to` relationships automatically get the destination resource's
generated ObjectId type:

```elixir
defmodule MyApp.Blog.Comment do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "comment"
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :post, MyApp.Blog.Post do
      allow_nil? false
      public? true
    end
  end
end
```

The generated `post_id` attribute uses `MyApp.Blog.Post.ObjectId`, so this works:

```elixir
MyApp.Blog.Comment
|> Ash.Changeset.for_create(:create, %{
  body: "Nice post",
  post_id: post.id
})
|> Ash.create!()
```

The database still stores a UUID foreign key.

## What Gets Generated

Each resource gets a nested ObjectId type:

```elixir
MyApp.Blog.Post.ObjectId
```

That type:

- stores as `:uuid`
- accepts `post_...` input
- dumps prefixed IDs to native UUIDs
- casts stored UUIDs back to `post_...`
- exposes GraphQL fields as `:id`
- exposes AshTypescript fields as `string` by default

## Next Steps

- Use [PostgreSQL UUIDv7](postgres-uuidv7.md) if you want database-side UUIDv7 defaults.
- Use [API Integrations](api-integrations.md) when exposing resources through GraphQL, JSON:API, TypeScript, or Phoenix routes.
- Use [Legacy Prefixes](legacy-prefixes.md) before renaming an existing prefix.
