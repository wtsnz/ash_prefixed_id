defmodule AshPrefixedId.Prefix do
  @moduledoc """
  Validation helpers for prefixed ID prefixes.

  Prefixes follow the TypeID prefix shape: lowercase ASCII letters and
  underscores, starting and ending with a letter, with a maximum length of 63.
  """

  @max_length 63

  @type validation_error ::
          :not_a_string
          | :empty
          | :too_long
          | :invalid_start
          | :invalid_end
          | :invalid_characters

  @spec validate(term()) :: :ok | {:error, validation_error()}
  def validate(prefix) when not is_binary(prefix), do: {:error, :not_a_string}

  def validate(""), do: {:error, :empty}

  def validate(prefix) when byte_size(prefix) > @max_length, do: {:error, :too_long}

  def validate(prefix) do
    cond do
      not lowercase_letter?(first_byte(prefix)) ->
        {:error, :invalid_start}

      not lowercase_letter?(last_byte(prefix)) ->
        {:error, :invalid_end}

      not valid_characters?(prefix) ->
        {:error, :invalid_characters}

      true ->
        :ok
    end
  end

  @spec validate!(term()) :: String.t()
  def validate!(prefix) do
    case validate(prefix) do
      :ok ->
        prefix

      {:error, reason} ->
        raise ArgumentError, "invalid prefixed ID prefix #{inspect(prefix)}: #{message(reason)}"
    end
  end

  @spec valid?(term()) :: boolean()
  def valid?(prefix), do: validate(prefix) == :ok

  @spec message(validation_error()) :: String.t()
  def message(:not_a_string), do: "must be a string"
  def message(:empty), do: "must not be empty"
  def message(:too_long), do: "must be no more than 63 characters"
  def message(:invalid_start), do: "must start with a lowercase ASCII letter"
  def message(:invalid_end), do: "must end with a lowercase ASCII letter"

  def message(:invalid_characters),
    do: "must contain only lowercase ASCII letters and underscores"

  defp first_byte(<<first, _rest::binary>>), do: first

  defp last_byte(prefix), do: :binary.last(prefix)

  defp lowercase_letter?(byte), do: byte in ?a..?z

  defp valid_characters?(prefix) do
    prefix
    |> :binary.bin_to_list()
    |> Enum.all?(&(&1 in ?a..?z or &1 == ?_))
  end
end
