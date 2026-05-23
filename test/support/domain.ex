defmodule AshPrefixedId.Test.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource(AshPrefixedId.Test.Resources.Post)
    resource(AshPrefixedId.Test.Resources.Comment)
    resource(AshPrefixedId.Test.Resources.Unrelated)
    resource(AshPrefixedId.Test.Resources.PostgresPost)
  end
end
