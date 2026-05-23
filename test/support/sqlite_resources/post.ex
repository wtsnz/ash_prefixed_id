defmodule AshPrefixedId.Test.SqliteResources.Post do
  @moduledoc false

  use Ash.Resource,
    domain: AshPrefixedId.Test.SqliteDomain,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "sqlite_post"
  end

  sqlite do
    table("ashsqlite_posts")
    repo(AshPrefixedId.Test.SqliteRepo)
  end

  actions do
    defaults([:read, :destroy, create: [:title], update: [:title]])
  end

  attributes do
    uuid_v7_primary_key(:id)
    attribute(:title, :string, public?: true)
  end

  relationships do
    has_many(:comments, AshPrefixedId.Test.SqliteResources.Comment)
  end
end
