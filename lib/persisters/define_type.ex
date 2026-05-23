defmodule AshPrefixedId.Persisters.DefineType do
  @moduledoc false
  use Spark.Dsl.Transformer

  def transform(dsl) do
    prefix = AshPrefixedId.Info.prefixed_id_prefix!(dsl)
    accepted_prefixes = [prefix | AshPrefixedId.Info.prefixed_id_legacy_prefixes!(dsl)]

    typescript_brand? =
      case AshPrefixedId.Info.prefixed_id_typescript_brand?(dsl) do
        {:ok, value} when is_boolean(value) -> value
        value when is_boolean(value) -> value
        _ -> false
      end

    typescript_type_name =
      AshPrefixedId.Type.typescript_type_name(
        accepted_prefixes,
        typescript_brand?
      )

    module = Spark.Dsl.Transformer.get_persisted(dsl, :module)

    {dsl, uuid_type, primary_key} =
      case Ash.Resource.Info.primary_key(dsl) do
        [pk] ->
          attr = Ash.Resource.Info.attribute(dsl, pk)
          example = attr.type.generator(attr.constraints) |> Enum.take(1) |> hd()

          if Ecto.UUID.cast(example) == :error do
            raise Spark.Error.DslError,
              module: module,
              message: "Expected a UUID type for the primary key",
              path: [:attributes, pk]
          end

          uuid_type = attr.type
          new_type = Module.concat(module, ObjectId)

          attr = %{
            attr
            | type: new_type,
              default: {AshPrefixedId.Type, :generate, [uuid_type, prefix, attr.constraints]}
          }

          dsl =
            Spark.Dsl.Transformer.replace_entity(dsl, [:attributes], attr, fn record ->
              record.__struct__ == attr.__struct__ && record.name == attr.name
            end)

          {dsl, uuid_type, pk}

        [] ->
          raise Spark.Error.DslError,
            module: module,
            message: "Missing UUID primary key attribute",
            path: [:attributes]

        _ ->
          raise Spark.Error.DslError,
            module: module,
            message: "Expected only a single primary key UUID attribute.",
            path: [:attributes]
      end

    dsl =
      Spark.Dsl.Transformer.eval(
        dsl,
        [
          uuid_type: uuid_type,
          prefix: prefix,
          accepted_prefixes: accepted_prefixes,
          typescript_type_name: typescript_type_name
        ],
        quote do
          defmodule ObjectId do
            use Ash.Type

            @impl Ash.Type
            defdelegate storage_type(constraints), to: unquote(uuid_type)

            @impl Ash.Type
            def cast_input(input, constraints) do
              AshPrefixedId.Type.cast_input(
                unquote(uuid_type),
                unquote(accepted_prefixes),
                input,
                constraints
              )
            end

            @impl Ash.Type
            def cast_stored(input, constraints) do
              AshPrefixedId.Type.cast_stored(
                unquote(uuid_type),
                unquote(prefix),
                input,
                constraints
              )
            end

            @impl Ash.Type
            def dump_to_native(input, constraints) do
              AshPrefixedId.Type.dump_to_native(
                unquote(uuid_type),
                unquote(accepted_prefixes),
                input,
                constraints
              )
            end

            @impl Ash.Type
            def dump_to_embedded(value, constraints) do
              cast_input(value, constraints)
            end

            @impl Ash.Type
            def equal?(term1, term2) do
              AshPrefixedId.Type.equal?(unquote(prefix), term1, term2)
            end

            @impl Ash.Type
            def matches_type?(value, constraints) do
              case cast_input(value, constraints) do
                {:ok, _} -> true
                _ -> false
              end
            end

            @impl Ash.Type
            def cast_atomic(new_value, constraints) do
              unquote(uuid_type).cast_atomic(new_value, constraints)
            end

            @impl Ash.Type
            def generator(constraints) do
              AshPrefixedId.Type.generator(unquote(uuid_type), unquote(prefix), constraints)
            end

            def graphql_type(_constraints), do: :id

            def graphql_input_type(_constraints), do: :id

            def typescript_type_name, do: unquote(typescript_type_name)
          end
        end
      )

    dsl = maybe_define_phoenix_param(dsl, module, primary_key)

    # Update FK attributes for belongs_to relationships pointing to AshPrefixedId resources
    dsl = update_fk_attributes(dsl, module)

    {:ok, dsl}
  end

  defp maybe_define_phoenix_param(dsl, module, primary_key) do
    case AshPrefixedId.Info.prefixed_id_phoenix_param?(dsl) do
      value when value in [true, {:ok, true}] ->
        Spark.Dsl.Transformer.eval(
          dsl,
          [module: module, primary_key: primary_key],
          quote do
            case Code.ensure_compiled(Phoenix.Param) do
              {:module, Phoenix.Param} ->
                defimpl Phoenix.Param, for: unquote(module) do
                  def to_param(resource) do
                    resource
                    |> Map.fetch!(unquote(primary_key))
                    |> to_string()
                  end
                end

              _ ->
                :ok
            end
          end
        )

      _ ->
        dsl
    end
  end

  # Scans belongs_to relationships and updates FK attribute types to use
  # the destination resource's ObjectId type (if available).
  defp update_fk_attributes(dsl, module) do
    dsl
    |> Spark.Dsl.Transformer.get_entities([:relationships])
    |> Enum.filter(&(&1.type == :belongs_to))
    |> Enum.reduce(dsl, fn relationship, dsl ->
      case resolve_destination_object_id(dsl, module, relationship) do
        {:ok, object_id_type} ->
          attr = Ash.Resource.Info.attribute(dsl, relationship.source_attribute)

          if attr && attr.type != object_id_type do
            updated_attr = %{attr | type: object_id_type}

            Spark.Dsl.Transformer.replace_entity(dsl, [:attributes], updated_attr, fn record ->
              record.__struct__ == attr.__struct__ && record.name == attr.name
            end)
          else
            dsl
          end

        :skip ->
          dsl
      end
    end)
  end

  defp resolve_destination_object_id(dsl, source_module, relationship) do
    destination = relationship.destination

    destination_dsl =
      if destination == source_module do
        dsl
      else
        try do
          destination.spark_dsl_config()
        rescue
          _ -> nil
        end
      end

    if destination_dsl do
      case AshPrefixedId.Info.prefixed_id_prefix(destination_dsl) do
        {:ok, _prefix} ->
          # The ObjectId module will be defined by the destination's DefineType
          # persister. It may not exist yet at compile time (compilation order
          # varies), but replace_entity doesn't validate types, and the module
          # will exist by runtime.
          {:ok, Module.concat(destination, ObjectId)}

        _ ->
          :skip
      end
    else
      :skip
    end
  end
end
