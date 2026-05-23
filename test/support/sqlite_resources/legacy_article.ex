defmodule AshPrefixedId.Test.SqliteResources.LegacyArticle do
  @moduledoc false

  use Ash.Resource,
    domain: AshPrefixedId.Test.SqliteDomain,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "sqlite_article"
    legacy_prefixes ["sqlite_old_article"]
  end

  sqlite do
    table("ashsqlite_legacy_articles")
    repo(AshPrefixedId.Test.SqliteRepo)
  end

  actions do
    defaults([:read, :destroy, create: [:title], update: [:title]])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true)
  end
end
