defmodule AshPrefixedId.PhoenixParamTest do
  use ExUnit.Case, async: true

  test "phoenix_param? implements Phoenix.Param with the prefixed primary key" do
    module = AshPrefixedId.Test.Resources.PhoenixRoute
    id = AshPrefixedId.Type.generate(Ash.Type.UUID, "route_param", [])

    assert Phoenix.Param.to_param(struct(module, id: id)) == id
  end
end
