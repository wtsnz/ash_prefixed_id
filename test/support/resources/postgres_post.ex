defmodule AshPrefixedId.Test.Resources.PostgresPost do
  @moduledoc false

  use Ash.Resource,
    domain: AshPrefixedId.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "pgpost"
    migration_default?(true)
  end

  postgres do
    table("postgres_posts")
    repo(AshPrefixedId.Test.Repo)
  end

  actions do
    defaults([:read, :destroy, create: [:title], update: [:title]])
  end

  attributes do
    uuid_v7_primary_key(:id)
    attribute(:title, :string, public?: true)
  end
end
