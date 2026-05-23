defmodule AshPrefixedId.Test.CustomUuidType do
  @moduledoc false

  use Ash.Type

  @impl true
  def storage_type(_constraints), do: :uuid

  @impl true
  def cast_input(value, _constraints), do: Ecto.UUID.cast(value)

  @impl true
  def cast_stored(value, _constraints), do: Ecto.UUID.cast(value)

  @impl true
  def dump_to_native(value, _constraints), do: Ecto.UUID.dump(value)

  @impl true
  def generator(_constraints), do: StreamData.constant(Ecto.UUID.generate())
end
