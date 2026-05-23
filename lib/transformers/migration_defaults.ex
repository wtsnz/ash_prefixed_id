if Code.ensure_loaded?(AshPostgres.DataLayer) do
  defmodule AshPrefixedId.Transformers.MigrationDefaults do
    @moduledoc """
    Sets PostgreSQL migration defaults for ObjectId primary key attributes.

    When `migration_default?` is enabled in the `prefixed_id` DSL, this transformer
    adds `fragment("uuid_generate_v7()")` as the migration default for the primary
    key. This ensures UUIDs are generated database-side for raw SQL inserts and seeds.

    Requires the `AshPrefixedId.PostgresExtension` to be installed in your repo.
    """
    use Spark.Dsl.Transformer

    alias Spark.Dsl.Transformer

    def after?(_), do: true

    def transform(dsl_state) do
      data_layer = Transformer.get_persisted(dsl_state, :data_layer)

      dsl_state =
        if data_layer == AshPostgres.DataLayer do
          case AshPrefixedId.Info.prefixed_id_migration_default?(dsl_state) do
            truthy when truthy in [true, {:ok, true}] ->
              [pk] = Ash.Resource.Info.primary_key(dsl_state)
              function = AshPrefixedId.Info.prefixed_id_migration_default_function!(dsl_state)
              validate_function!(dsl_state, function)

              migration_defaults =
                [{pk, "fragment(#{inspect(function)})"}]
                |> Keyword.merge(
                  Transformer.get_option(dsl_state, [:postgres], :migration_defaults) || []
                )

              Transformer.set_option(
                dsl_state,
                [:postgres],
                :migration_defaults,
                migration_defaults
              )

            _ ->
              dsl_state
          end
        else
          dsl_state
        end

      {:ok, dsl_state}
    end

    defp validate_function!(dsl_state, function) do
      if Regex.match?(~r/\A[a-z_][a-z0-9_]*(?:\.[a-z_][a-z0-9_]*)?\(\)\z/, function) do
        :ok
      else
        module = Transformer.get_persisted(dsl_state, :module)

        raise Spark.Error.DslError,
          module: module,
          path: [:prefixed_id, :migration_default_function],
          message:
            "Invalid migration_default_function #{inspect(function)}. Expected a zero-arity PostgreSQL function like \"uuidv7()\" or \"extensions.uuidv7()\"."
      end
    end
  end
end
