defmodule AshPrefixedId.Test.Resources.PostgresNativePost do
  @moduledoc false

  use Ash.Resource,
    domain: AshPrefixedId.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "pgnative"
    migration_default?(true)
    migration_default_function "uuidv7()"
  end

  postgres do
    table("postgres_native_posts")
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
