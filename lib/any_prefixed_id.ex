defmodule AshPrefixedId.AnyPrefixedId do
  @moduledoc """
  A universal PrefixedId type that accepts any prefixed ID.

  This type is useful as a global replacement for `:uuid` when you want UUID
  arguments, manual attributes, or non-`AshPrefixedId` resources to accept
  prefixed IDs.

  ## Usage

  Register as a custom type in your Ash config:

      config :ash,
        custom_types: [uuid: AshPrefixedId.AnyPrefixedId]

  This replaces the standard `Ash.Type.UUID` for all `:uuid` references in Ash,
  making them accept both prefixed IDs (`"user_CWzLBdFy2f1XhrtesFferY"`) and raw
  UUIDs (`"550e8400-e29b-41d4-a716-446655440000"`).

  ## Behavior

  - Input accepts any syntactically valid prefixed ID or raw UUID string.
  - Dumping a prefixed ID stores the underlying UUID binary.
  - Stored values cast back as raw UUID strings, because this type has no
    resource context and cannot know which prefix to reapply.

  Use generated resource-specific ObjectId types when outputs must render with a
  resource prefix.
  """

  use Ash.Type

  @impl true
  def storage_type(_constraints), do: :uuid

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(input, _constraints) when is_binary(input) do
    case AshPrefixedId.Type.decode_object_id(input) do
      {:ok, _prefix, _uuid} ->
        {:ok, input}

      _ ->
        # Fall back to standard UUID casting for raw UUIDs
        case Ecto.UUID.cast(input) do
          {:ok, _} -> {:ok, input}
          :error -> :error
        end
    end
  end

  def cast_input(_, _constraints), do: :error

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}

  def cast_stored(input, constraints) do
    Ash.Type.UUID.cast_stored(input, constraints)
  end

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}

  def dump_to_native(input, _constraints) when is_binary(input) do
    case AshPrefixedId.Type.decode_object_id(input) do
      {:ok, _prefix, uuid_binary} ->
        {:ok, uuid_binary}

      _ ->
        # Fall back to standard UUID dumping
        Ecto.UUID.dump(input)
    end
  end

  def dump_to_native(_, _constraints), do: :error

  @impl true
  def generator(_constraints) do
    StreamData.repeatedly(fn ->
      Ecto.UUID.bingenerate() |> Ecto.UUID.cast!()
    end)
  end

  def graphql_type(_constraints), do: :id

  def graphql_input_type(_constraints), do: :id

  def typescript_type_name, do: "string"
end
