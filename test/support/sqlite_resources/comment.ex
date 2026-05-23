defmodule AshPrefixedId.Test.SqliteResources.Comment do
  @moduledoc false

  alias AshPrefixedId.Test.SqliteResources.Post

  use Ash.Resource,
    domain: AshPrefixedId.Test.SqliteDomain,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "sqlite_comment"
  end

  sqlite do
    table("ashsqlite_comments")
    repo(AshPrefixedId.Test.SqliteRepo)
  end

  actions do
    defaults([:read, :destroy, create: [:body, :post_id], update: [:body]])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:body, :string, public?: true)
  end

  relationships do
    belongs_to(:post, Post)
  end
end
