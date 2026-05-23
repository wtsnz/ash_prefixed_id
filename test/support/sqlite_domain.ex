defmodule AshPrefixedId.Test.SqliteDomain do
  @moduledoc false

  use Ash.Domain

  resources do
    resource(AshPrefixedId.Test.SqliteResources.Post)
    resource(AshPrefixedId.Test.SqliteResources.Comment)
    resource(AshPrefixedId.Test.SqliteResources.LegacyArticle)
  end
end
