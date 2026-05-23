defmodule AshPrefixedId.ParsedId do
  @moduledoc """
  Parsed components of a prefixed ID.
  """

  @enforce_keys [:prefix, :slug, :uuid, :uuid_binary]
  defstruct [:prefix, :slug, :uuid, :uuid_binary]

  @type t :: %__MODULE__{
          prefix: String.t(),
          slug: String.t(),
          uuid: String.t(),
          uuid_binary: binary()
        }
end
