defmodule AshPrefixedId do
  @moduledoc """
  An extension for working with prefixed IDs.

  Prefixed IDs are external identifiers that include a short resource prefix,
  for example `user_CWzLBdFy2f1XhrtesFferY`. They are easier to inspect in logs,
  API payloads, URLs, support tickets, and dashboards than bare UUIDs. A more
  detailed explanation of the API design pattern is available in Stripe's
  ["Designing APIs for humans"](https://dev.to/stripe/designing-apis-for-humans-object-ids-3o5a).

  `AshPrefixedId` keeps database storage native. Primary and foreign keys remain
  UUID values in the data layer, while Ash resources and API clients see prefixed
  strings.

  ## Resource Setup

      defmodule App.Blog.Post do
        use Ash.Resource,
          domain: App.Blog,
          data_layer: AshPostgres.DataLayer,
          extensions: [AshPrefixedId]

        prefixed_id do
          prefix "post"
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:title, :string, public?: true)
        end
      end

  The primary key must use `uuid_primary_key/2` or `uuid_v7_primary_key/2`.
  Custom UUID-like primary key types are intentionally rejected until they can be
  supported with clear casting and dumping semantics.

  The configured prefix is validated at compile time. Prefixes must:

  - contain only lowercase ASCII letters and underscores
  - start and end with a lowercase ASCII letter
  - be no longer than 63 characters

  Each resource gets a generated `<resource>.ObjectId` Ash type. For the module
  above, `App.Blog.Post.ObjectId` stores as `:uuid`, casts external
  `post_...` strings, and renders stored UUIDs back as `post_...`.

  ## Relationships

  Foreign key attributes for `belongs_to` relationships pointing at resources
  that use this extension are automatically rewritten to the destination
  resource's ObjectId type:

      relationships do
        belongs_to :post, App.Blog.Post
        # post_id is auto-created as App.Blog.Post.ObjectId
      end

  This keeps relationship inputs and API payloads using prefixed IDs while the
  database still stores UUID foreign keys.

  ## Legacy Prefixes

  Use `legacy_prefixes` when a resource has been renamed or an API prefix needs
  to change without breaking existing clients:

      prefixed_id do
        prefix "account"
        legacy_prefixes ["user"]
      end

  New values generate as `account_...`. Incoming `user_...` values are accepted
  and canonicalized back to `account_...` at the Ash type boundary.

  ## PostgreSQL Defaults

  With AshPostgres, `migration_default? true` adds a database-side UUIDv7
  default for the primary key in generated migrations:

      prefixed_id do
        prefix "post"
        migration_default? true
      end

  The default function is `uuid_generate_v7()`, provided by
  `AshPrefixedId.PostgresExtension`. PostgreSQL 18 users can use the native
  function instead:

      prefixed_id do
        prefix "post"
        migration_default? true
        migration_default_function "uuidv7()"
      end

  `migration_default_function` must be a zero-arity PostgreSQL function name,
  such as `uuidv7()` or `extensions.uuidv7()`.

  ## API Integrations

  Generated ObjectId types expose GraphQL fields as `:id` and AshTypescript
  fields as `string` by default. For stricter TypeScript clients:

      prefixed_id do
        prefix "post"
        typescript_brand? true
      end

  AshTypescript will then see `string & { readonly __prefix: "post" }`.

  Phoenix route helpers can use prefixed primary keys directly:

      prefixed_id do
        prefix "post"
        phoenix_param? true
      end

  When enabled, `Phoenix.Param` must be available while the resource compiles.

  ## Global Lookup

  `resource/2` and `get/3` resolve an incoming prefixed ID against an explicit
  domain allowlist:

      AshPrefixedId.resource([MyApp.Accounts, MyApp.Blog], "post_...")
      AshPrefixedId.get([MyApp.Accounts, MyApp.Blog], "post_...", actor: actor)

  Duplicate prefixes across the allowed domains are reported as an ambiguity
  instead of guessing.

  ## Data Layer Support

  The core ObjectId type stores as `:uuid`, so the prefix/cast/render behavior
  is not inherently tied to Postgres. ETS and AshSqlite are covered by the root
  test suite, and AshPostgres is covered by the example app. Database-side
  UUIDv7 defaults and `AshPrefixedId.PostgresExtension` are AshPostgres-only.

  For AshSqlite, configure Ecto SQLite binary UUID storage before generating
  migrations if you want raw 16-byte UUID values in the database:

      config :ecto_sqlite3, :uuid_type, :binary

  Other data layers should work for normal type behavior if they support Ash UUID
  storage. They should not use `migration_default?` unless they provide
  compatible migration support.
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
                     AshPrefixedId.Transformers.MigrationDefaults
                   ]
                 else
                   [
                     AshPrefixedId.Transformers.ValidatePrefix
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
      migration_default_function: [
        type: :string,
        doc:
          "The PostgreSQL UUID function to use when `migration_default?` is true. Use `uuidv7()` on PostgreSQL 18+.",
        default: "uuid_generate_v7()"
      ],
      typescript_brand?: [
        type: :boolean,
        doc:
          "When true, generated ObjectId types expose a branded TypeScript string instead of plain `string`.",
        default: false
      ],
      phoenix_param?: [
        type: :boolean,
        doc:
          "When true and Phoenix is available, implements `Phoenix.Param` for the resource using its prefixed primary key.",
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

  Prefer this over `find_resource_for_id/2` when the caller needs to distinguish
  invalid input, unknown prefixes, and ambiguous prefixes.
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

  This function is intentionally allowlist-based. Pass only the Ash domains that
  should be visible to the current boundary, for example the domains exposed by
  an admin API or a webhook endpoint.
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
  contain more than one resource for the given prefix.

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
