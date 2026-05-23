defmodule AshPrefixedId do
  @moduledoc """
  An extension for working with prefixed IDs.

  Prefixed IDs are identifiers that are prefixed with the resource they identify.
  A more detailed explanation can be found in the ["Designing APIs for
  humans"](https://dev.to/stripe/designing-apis-for-humans-object-ids-3o5a) blog post.

  This library provides an implementation for Ash:

      defmodule App.Blog.Post do
        use Ash.Resource,
          domain: App.Blog,
          data_layer: Ash.DataLayer.AshPostgres,
          extensions: [AshPrefixedId]

        prefixed_id do
          prefix "p"
        end

        attributes do
          uuid_primary_key(:id)
          # ... other attributes
        end
      end

  `AshPrefixedId` replaces the `:id` primary key with a prefixed ID (prefixed by "p").
  The underlying UUID implementation will be used, so it works with both UUID
  and UUIDv7. The IDs are stored as regular UUIDs in the database. Externally,
  the UUIDs are encoded as "{prefix}_{base58(uuid)}".

  Each resource will have a generated `<resource>.ObjectId` module which is the
  `Ash.Type` for that ID. Foreign key attributes for `belongs_to` relationships
  are automatically created with the correct ObjectId type:

      relationships do
        belongs_to :post, App.Blog.Post
        # post_id attribute is auto-created as App.Blog.Post.ObjectId
      end
  """

  alias AshPrefixedId.ParsedId
  alias AshPrefixedId.Type

  @type parse_error ::
          :not_a_string
          | :missing_separator
          | :empty_prefix
          | :empty_suffix
          | AshPrefixedId.Prefix.validation_error()
          | :invalid_suffix
          | :invalid_uuid

  @type resource_lookup_error ::
          {:invalid_id, parse_error()}
          | :unknown_prefix
          | {:ambiguous_prefix, String.t(), [module()]}

  @transformers (if Code.ensure_loaded?(AshPostgres.DataLayer) do
                   [
                     AshPrefixedId.Transformers.ValidatePrefix,
                     AshPrefixedId.Transformers.BelongsToAttribute,
                     AshPrefixedId.Transformers.MigrationDefaults
                   ]
                 else
                   [
                     AshPrefixedId.Transformers.ValidatePrefix,
                     AshPrefixedId.Transformers.BelongsToAttribute
                   ]
                 end)

  @persisters [
    AshPrefixedId.Persisters.DefineType
  ]

  @prefixed_id %Spark.Dsl.Section{
    name: :prefixed_id,
    describe: "Use prefixed ID for identifier of a resource",
    examples: [
      """
      prefixed_id do
        prefix "u"
      end
      """
    ],
    schema: [
      prefix: [
        type: :string,
        doc: "The prefix to use for the given resource",
        required: true
      ],
      legacy_prefixes: [
        type: {:list, :string},
        doc: "Additional old prefixes accepted for this resource when parsing incoming IDs.",
        default: []
      ],
      migration_default?: [
        type: :boolean,
        doc:
          "When true, adds `uuid_generate_v7()` as the PostgreSQL migration default for the primary key. Requires `AshPrefixedId.PostgresExtension` to be installed.",
        default: false
      ],
      typescript_brand?: [
        type: :boolean,
        doc:
          "When true, generated ObjectId types expose a branded TypeScript string instead of plain `string`.",
        default: false
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@prefixed_id],
    transformers: @transformers,
    persisters: @persisters

  @doc """
  Parses a prefixed ID into its prefix, encoded slug, and UUID forms.

  ## Examples

      iex> {:ok, parsed} = parse("user_CWzLBdFy2f1XhrtesFferY")
      iex> parsed.prefix
      "user"
      iex> parsed.uuid
      "5d446d08-df6a-404d-a1e5-decc78429b3d"
  """
  @spec parse(term()) :: {:ok, ParsedId.t()} | {:error, parse_error()}
  def parse(id) do
    case Type.parse_object_id(id) do
      {:ok, prefix, slug, uuid_binary} ->
        case Ecto.UUID.load(uuid_binary) do
          {:ok, uuid} ->
            {:ok,
             %ParsedId{
               prefix: prefix,
               slug: slug,
               uuid: uuid,
               uuid_binary: uuid_binary
             }}

          :error ->
            {:error, :invalid_uuid}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parses a prefixed ID or raises `ArgumentError`.
  """
  @spec parse!(term()) :: ParsedId.t()
  def parse!(id) do
    case parse(id) do
      {:ok, parsed} ->
        parsed

      {:error, reason} ->
        raise ArgumentError, "invalid prefixed ID (#{reason}): #{inspect(id)}"
    end
  end

  @doc """
  Returns true when the value is a syntactically valid prefixed ID.
  """
  @spec valid?(term()) :: boolean()
  def valid?(id), do: match?({:ok, _parsed}, parse(id))

  @doc """
  Extracts the prefix from a prefixed ID.
  """
  @spec prefix(term()) :: {:ok, String.t()} | {:error, parse_error()}
  def prefix(id) do
    case parse(id) do
      {:ok, %ParsedId{prefix: prefix}} -> {:ok, prefix}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extracts the prefix from a prefixed ID or raises `ArgumentError`.
  """
  @spec prefix!(term()) :: String.t()
  def prefix!(id), do: parse!(id).prefix

  @doc """
  Decodes the given prefixed ID into a string version of the UUID.

  ## Examples

      iex> decode_object_id("user_CWzLBdFy2f1XhrtesFferY")
      {:ok, "5d446d08-df6a-404d-a1e5-decc78429b3d"}

      iex> decode_object_id("florb_CWzLBdFy2f1XhrtesFferY")
      :error

      iex> decode_object_id("something else")
      :error
  """
  @spec decode_object_id(binary()) :: {:ok, String.t()} | :error
  def decode_object_id(id) do
    case Type.decode_object_id(id) do
      {:ok, _prefix, uuid_bin} -> Ecto.UUID.load(uuid_bin)
      :error -> :error
    end
  end

  @doc """
  Searches the given domains for the resource that matches the given prefixed ID
  prefix.

  You can get the domains through `Application.get_env(:my_otp_app, :ash_domains, [])`

  ## Examples

      iex> find_resource_for_prefix(domains, "user")
      MyApp.Accounts.User

      iex> find_resource_for_prefix(domains, "florb")
      nil
  """
  def find_resource_for_prefix(domains, prefix) when is_binary(prefix) and is_list(domains) do
    domains
    |> resources_for_prefix(prefix)
    |> List.first()
  end

  @doc """
  Same as `find_resource_for_prefix/2` but accepts a (valid) prefixed ID.

  ## Examples

      iex> find_resource_for_id(domains, "user_CWzLBdFy2f1XhrtesFferY")
      MyApp.Accounts.User

      iex> find_resource_for_id(domains, "florb_CWzLBdFy2f1XhrtesFferY")
      nil
  """
  @spec find_resource_for_id([module()], String.t()) :: module() | nil
  def find_resource_for_id(domains, id) when is_list(domains) and is_binary(id) do
    case Type.decode_object_id(id) do
      {:ok, prefix, _uuid} -> find_resource_for_prefix(domains, prefix)
      _ -> nil
    end
  end

  @doc """
  Returns all resources in the given domains that accept a prefix.
  """
  @spec resources_for_prefix([module()], String.t()) :: [module()]
  def resources_for_prefix(domains, prefix) when is_list(domains) and is_binary(prefix) do
    domains
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
    |> Enum.filter(&(prefix in prefixes_for_resource(&1)))
  end

  @doc """
  Finds the resource for a prefixed ID with explicit errors.
  """
  @spec resource([module()], String.t()) :: {:ok, module()} | {:error, resource_lookup_error()}
  def resource(domains, id) when is_list(domains) and is_binary(id) do
    case Type.parse_object_id(id) do
      {:ok, prefix, _slug, _uuid} -> resource_for_prefix(domains, prefix)
      {:error, reason} -> {:error, {:invalid_id, reason}}
    end
  end

  @doc """
  Finds the resource for a prefixed ID or raises `ArgumentError`.
  """
  @spec resource!([module()], String.t()) :: module()
  def resource!(domains, id) do
    case resource(domains, id) do
      {:ok, resource} -> resource
      {:error, error} -> raise ArgumentError, resource_lookup_error_message(error)
    end
  end

  @doc """
  Looks up a record by prefixed ID after resolving its resource from allowed domains.

  Options are passed through to `Ash.get/3`, so `:actor`, `:authorize?`,
  `:tenant`, and other Ash options continue to work.
  """
  @spec get([module()], String.t(), Keyword.t()) :: {:ok, struct()} | {:error, term()}
  def get(domains, id, opts \\ []) when is_list(domains) and is_binary(id) and is_list(opts) do
    with {:ok, resource} <- resource(domains, id) do
      Ash.get(resource, id, opts)
    end
  end

  @doc """
  Looks up a record by prefixed ID or raises.
  """
  @spec get!([module()], String.t(), Keyword.t()) :: struct()
  def get!(domains, id, opts \\ []) when is_list(domains) and is_binary(id) and is_list(opts) do
    case resource(domains, id) do
      {:ok, resource} -> Ash.get!(resource, id, opts)
      {:error, error} -> raise ArgumentError, resource_lookup_error_message(error)
    end
  end

  @doc """
  Create a map of prefixes to the resources that use that prefix.
  """
  @spec map_prefixes_to_resources([module()]) :: %{String.t() => [module()]}
  def map_prefixes_to_resources(domains) do
    Enum.reduce(domains, %{}, fn domain, mapping ->
      domain
      |> Ash.Domain.Info.resources()
      |> Enum.reduce(mapping, fn resource, mapping ->
        Enum.reduce(prefixes_for_resource(resource), mapping, fn prefix, mapping ->
          Map.update(mapping, prefix, [resource], &[resource | &1])
        end)
      end)
    end)
  end

  @doc """
  Returns the primary prefix followed by any legacy prefixes for a resource.
  """
  @spec prefixes_for_resource(module()) :: [String.t()]
  def prefixes_for_resource(resource) do
    case AshPrefixedId.Info.prefixed_id_prefix(resource) do
      {:ok, prefix} -> [prefix | legacy_prefixes_for_resource(resource)]
      _ -> []
    end
  end

  @doc """
  Same as `map_prefixes_to_resources`, but returns only the entries that
  contain more than resource for the given prefix.

  This function can be used to warn whenever duplicate prefixes are present in
  your modules.
  """
  @spec find_duplicate_prefixes([module()]) :: %{String.t() => [module()]}
  def find_duplicate_prefixes(domains) do
    domains
    |> map_prefixes_to_resources()
    |> Map.filter(fn
      {_key, [_]} -> false
      _ -> true
    end)
  end

  @doc """
  Convert a prefixed ID to a 16-byte UUID binary for raw SQL fragments.

  ## Examples

      iex> to_uuid!("user_CWzLBdFy2f1XhrtesFferY")
      <<93, 68, 109, 8, ...>>  # 16-byte binary
  """
  @spec to_uuid!(binary()) :: binary()
  def to_uuid!(prefixed_id) when is_binary(prefixed_id) do
    case Type.decode_object_id(prefixed_id) do
      {:ok, _prefix, uuid_bin} -> uuid_bin
      _ -> raise ArgumentError, "invalid prefixed ID: #{inspect(prefixed_id)}"
    end
  end

  @doc """
  Convert a prefixed ID to a UUID string format.

  ## Examples

      iex> to_uuid_string!("user_CWzLBdFy2f1XhrtesFferY")
      "5d446d08-df6a-404d-a1e5-decc78429b3d"
  """
  @spec to_uuid_string!(binary()) :: String.t()
  def to_uuid_string!(prefixed_id) when is_binary(prefixed_id) do
    {:ok, uuid_string} = Ecto.UUID.cast(to_uuid!(prefixed_id))
    uuid_string
  end

  @doc """
  Convert a UUID binary or string to a prefixed ID.

  ## Examples

      iex> to_prefixed_id(<<93, 68, 109, 8, ...>>, "user")
      "user_CWzLBdFy2f1XhrtesFferY"
  """
  @spec to_prefixed_id(binary(), String.t()) :: String.t()
  def to_prefixed_id(uuid_bin_or_string, prefix) when is_binary(prefix) do
    Type.encode_uuid(uuid_bin_or_string, prefix)
  end

  defp legacy_prefixes_for_resource(resource) do
    case AshPrefixedId.Info.prefixed_id_legacy_prefixes(resource) do
      {:ok, legacy_prefixes} when is_list(legacy_prefixes) -> legacy_prefixes
      legacy_prefixes when is_list(legacy_prefixes) -> legacy_prefixes
      _ -> []
    end
  end

  defp resource_for_prefix(domains, prefix) do
    case resources_for_prefix(domains, prefix) do
      [] -> {:error, :unknown_prefix}
      [resource] -> {:ok, resource}
      resources -> {:error, {:ambiguous_prefix, prefix, resources}}
    end
  end

  defp resource_lookup_error_message({:invalid_id, reason}) do
    "invalid prefixed ID: #{reason}"
  end

  defp resource_lookup_error_message(:unknown_prefix), do: "unknown prefixed ID prefix"

  defp resource_lookup_error_message({:ambiguous_prefix, prefix, resources}) do
    "ambiguous prefixed ID prefix #{inspect(prefix)} for resources #{inspect(resources)}"
  end
end
