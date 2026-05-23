defmodule AshPrefixedId.Test.Resources.PhoenixRoute do
  @moduledoc false

  use Ash.Resource,
    domain: AshPrefixedId.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "route_param"
    phoenix_param?(true)
  end

  ets do
    private?(true)
  end

  actions do
    defaults([:read, :destroy, create: [:name], update: [:name]])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end
end
