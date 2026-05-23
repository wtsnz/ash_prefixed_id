defmodule AshPrefixedId.Transformers.ValidatePrefix do
  @moduledoc false
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    prefix = AshPrefixedId.Info.prefixed_id_prefix!(dsl_state)

    case AshPrefixedId.Prefix.validate(prefix) do
      :ok ->
        {:ok, dsl_state}

      {:error, reason} ->
        module = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)

        raise Spark.Error.DslError,
          module: module,
          path: [:prefixed_id, :prefix],
          message:
            "Invalid prefixed ID prefix #{inspect(prefix)}: #{AshPrefixedId.Prefix.message(reason)}"
    end
  end
end
