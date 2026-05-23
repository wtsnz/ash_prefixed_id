defmodule AshPrefixedId.Transformers.ValidatePrefix do
  @moduledoc false
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    prefix = AshPrefixedId.Info.prefixed_id_prefix!(dsl_state)
    legacy_prefixes = AshPrefixedId.Info.prefixed_id_legacy_prefixes!(dsl_state)

    with :ok <- validate_prefix(prefix, [:prefixed_id, :prefix]),
         :ok <- validate_legacy_prefixes(legacy_prefixes),
         :ok <- validate_unique_prefixes([prefix | legacy_prefixes]) do
      {:ok, dsl_state}
    else
      {:error, path, message} ->
        module = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)

        raise Spark.Error.DslError,
          module: module,
          path: path,
          message: message
    end
  end

  defp validate_legacy_prefixes(legacy_prefixes) do
    Enum.reduce_while(legacy_prefixes, :ok, fn prefix, :ok ->
      case validate_prefix(prefix, [:prefixed_id, :legacy_prefixes]) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_prefix(prefix, path) do
    case AshPrefixedId.Prefix.validate(prefix) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, path,
         "Invalid prefixed ID prefix #{inspect(prefix)}: #{AshPrefixedId.Prefix.message(reason)}"}
    end
  end

  defp validate_unique_prefixes(prefixes) do
    prefixes
    |> Enum.frequencies()
    |> Enum.find(fn {_prefix, count} -> count > 1 end)
    |> case do
      nil ->
        :ok

      {prefix, _count} ->
        {:error, [:prefixed_id, :legacy_prefixes],
         "Duplicate prefixed ID prefix #{inspect(prefix)} in prefix and legacy_prefixes"}
    end
  end
end
